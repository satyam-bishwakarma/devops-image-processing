# K3s and Jenkins host setup

The AWS demo used the Systems Manager bootstrap scripts. Run host setup on the Ubuntu EC2 instances created by [Terraform](../terraform/README.md), using the instance IDs and private IPs from its `hosts` output.

## K3s

Run `bootstrap-k3s-ssm.sh` as root on the control plane first, then on the worker. Set `K3S_REGION` and `K3S_NODE_IP` on both hosts. Set `K3S_NODE_MODE=server` on the control plane and `K3S_NODE_MODE=agent` on the worker. On the worker, also set `K3S_SERVER_IP` to the server's private address. Both hosts read the join token from the Systems Manager SecureString configured for the lab.

On the control plane, run `sudo k3s kubectl get nodes` and confirm both nodes report Ready. Use the [demo runbook](../../docs/runbooks/next-milestones.md) for the application and monitoring setup.

The `k3s.yml` playbook provides an alternative K3s setup for an Ansible controller with authenticated access to the hosts. Supply one host in each of `k3s_server` and `k3s_worker`, their `k3s_private_ip` values, and a shared `k3s_version`. Run `ansible-playbook -i inventory.yml k3s.yml` and check both nodes. The recorded AWS lab used the SSM scripts.

## Jenkins

1. Run `bootstrap-automation.sh` as root on the automation host. It starts the Docker engine and Jenkins controller on loopback port 8080.
2. Install Java 21 on the automation host and prepare the dedicated `jenkins-agent` Linux user. The user needs a writable `/home/jenkins-agent/worker` directory and subordinate UID and GID ranges for rootless Docker.
3. Run `bootstrap-jenkins-agent.sh` as root during setup. It restarts the controller to register `docker-agent`, then starts the systemd agent service with the rootless Docker socket.
4. In Jenkins, confirm the agent is online with the `docker` label. Create the Pipeline job from the private repository's `main` branch and its `Jenkinsfile`. Configure a repository checkout credential and the separate GHCR publishing credential named `ghcr-image-processing-publish`.

Keep the checkout token, registry token, agent secret, and real inventory credentials in their designated credential stores.
