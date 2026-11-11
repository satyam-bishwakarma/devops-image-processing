#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq uidmap dbus-user-session slirp4netns fuse-overlayfs curl apparmor
name=jenkins-agent
uid=$(id -u "$name")
agent_home=/home/jenkins-agent
bin=/opt/jenkins-docker/bin
export PATH="$bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
install -d -m 0755 "$bin"
if [ ! -x "$bin/dockerd-rootless-setuptool.sh" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  for package in docker docker-rootless-extras; do
    curl -fsSL --retry 3 "https://download.docker.com/linux/static/stable/x86_64/$package-29.9.3.tgz" -o "$tmp/$package.tgz"
    tar -xzf "$tmp/$package.tgz" --strip-components=1 -C "$bin"
  done
  chown -R root:root "$bin"
fi
if [ -d /sys/kernel/security/apparmor ]; then
  cat > /etc/apparmor.d/opt.jenkins-docker.bin.rootlesskit <<'PROFILE'
abi <abi/4.0>,
include <tunables/global>
"/opt/jenkins-docker/bin/rootlesskit" flags=(unconfined) {
  userns,
}
PROFILE
  apparmor_parser -r /etc/apparmor.d/opt.jenkins-docker.bin.rootlesskit
fi
loginctl enable-linger "$name"
systemctl start "user@$uid.service"
as_agent() {
  runuser -u "$name" -- env "PATH=$PATH" "XDG_RUNTIME_DIR=/run/user/$uid" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus" "$@"
}
if [ ! -f "$agent_home/.config/systemd/user/docker.service" ]; then
  as_agent "$bin/dockerd-rootless-setuptool.sh" install --force
fi
as_agent systemctl --user enable --now docker.service
as_agent env "DOCKER_HOST=unix:///run/user/$uid/docker.sock" docker info --format '{{json .SecurityOptions}}' | grep -q rootless
echo 'Rootless Docker verified'

controller=image-processing-jenkins
tmp_groovy=$(mktemp)
trap 'rm -f "$tmp_groovy"; if [ -n "${tmp:-}" ]; then rm -rf "$tmp"; fi' EXIT
cat > "$tmp_groovy" <<'GROOVY'
import hudson.model.Node
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher
import jenkins.model.Jenkins
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermissions

def jenkins = Jenkins.get()
def name = 'docker-agent'
if (jenkins.getNode(name) == null) {
    def node = new DumbSlave(name, '/home/jenkins-agent/worker', new JNLPLauncher())
    node.setLabelString('docker')
    node.setNumExecutors(1)
    node.setMode(Node.Mode.EXCLUSIVE)
    jenkins.addNode(node)
}
def computer = jenkins.getComputer(name)
assert computer != null
def root = jenkins.getRootDir().toPath()
def target = root.resolve('docker-agent.secret')
Files.deleteIfExists(target)
Files.createFile(target, PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString('rw-------')))
Files.writeString(target, computer.getJnlpMac())
GROOVY
docker exec --user 0 "$controller" mkdir -p /var/jenkins_home/init.groovy.d
docker cp "$tmp_groovy" "$controller:/var/jenkins_home/init.groovy.d/90-image-processing-agent.groovy"
docker exec --user 0 "$controller" chmod 0644 /var/jenkins_home/init.groovy.d/90-image-processing-agent.groovy
docker restart "$controller" >/dev/null
for attempt in $(seq 1 45); do
  if docker exec --user 0 "$controller" test -s /var/jenkins_home/docker-agent.secret; then break; fi
  sleep 2
done
docker exec --user 0 "$controller" test -s /var/jenkins_home/docker-agent.secret
install -d -o "$name" -g "$name" -m 0700 "$agent_home/.jenkins"
docker cp "$controller:/var/jenkins_home/docker-agent.secret" "$agent_home/.jenkins/agent.secret"
chown "$name:$name" "$agent_home/.jenkins/agent.secret"
chmod 0600 "$agent_home/.jenkins/agent.secret"
docker exec --user 0 "$controller" rm -f /var/jenkins_home/docker-agent.secret /var/jenkins_home/init.groovy.d/90-image-processing-agent.groovy
curl -fsS --retry 10 --retry-connrefused --retry-delay 3 http://127.0.0.1:8080/jnlpJars/agent.jar -o "$agent_home/.jenkins/agent.jar"
chown "$name:$name" "$agent_home/.jenkins/agent.jar"
cat > /etc/systemd/system/image-processing-jenkins-agent.service <<UNIT
[Unit]
Description=Image Processing Jenkins build agent
After=docker.service network-online.target user@$uid.service
Wants=network-online.target user@$uid.service

[Service]
User=$name
WorkingDirectory=$agent_home/worker
Environment=PATH=$PATH
Environment=DOCKER_HOST=unix:///run/user/$uid/docker.sock
ExecStart=/usr/bin/java -jar $agent_home/.jenkins/agent.jar -url http://127.0.0.1:8080/ -name docker-agent -webSocket -secret @$agent_home/.jenkins/agent.secret -workDir $agent_home/worker
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now image-processing-jenkins-agent.service
systemctl is-active image-processing-jenkins-agent.service