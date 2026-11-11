#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io curl
systemctl enable --now docker

if ! docker container inspect image-processing-jenkins >/dev/null 2>&1; then
  docker run -d --name image-processing-jenkins --restart unless-stopped \
    --publish 127.0.0.1:8080:8080 \
    --volume image-processing-jenkins-home:/var/jenkins_home \
    jenkins/jenkins:lts-jdk21
else
  docker start image-processing-jenkins
fi

docker version --format 'Docker engine {{.Server.Version}}'
for attempt in $(seq 1 40); do
  if curl -fsS --max-time 5 http://127.0.0.1:8080/login -o /dev/null; then
    echo 'Jenkins login endpoint ready on loopback port 8080'
    exit 0
  fi
  sleep 3
done
echo 'Jenkins did not become ready within the bootstrap timeout' >&2
exit 1
