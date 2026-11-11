# K3s bootstrap draft

Use a Linux Ansible controller with authenticated connectivity to the two EC2 hosts. Supply one host in k3s_server and one in k3s_worker. Set k3s_private_ip from Terraform output for each host and set k3s_version to the same verified K3s release in group vars. Configure the inventory's connection using the approved SSM or private SSH workflow.

Run ansible-playbook -i inventory.yml k3s.yml, then check that both nodes are Ready on the server. Run the play again to check repeatability. The installer tasks bootstrap fresh hosts and skip existing services. Plan release upgrades separately. Keep real inventory credentials out of Git.

This draft covers K3s only. Jenkins controller and agent configuration is a separate stage.
