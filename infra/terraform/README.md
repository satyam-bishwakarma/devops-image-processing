# AWS infrastructure

This Terraform configuration declares a shared VPC, a Jenkins/automation host, a K3s server and worker, and an EC2 instance profile for Systems Manager. It targets the project AWS account and defaults to ap-southeast-2. Each host has a public IPv4 address for outbound internet access. The security groups allow no public inbound connections. Administration uses Session Manager. An application entry point can be configured separately for the demo.

The default sizing is three Free-plan-eligible c7i-flex.large instances with 30 GiB encrypted gp3 volumes. Review regional compute, EBS, and public IPv4 costs and the credit balance before applying. Stop unused instances between lab sessions.

Run terraform init, terraform fmt -check, terraform validate, and terraform plan from this directory. Run the plan using an approved provisioning role. Keep state outside Git. The initial state is local. Migrate it to a team-controlled, versioned S3 backend with locking before multiple people operate the same stack.

The three team IAM identities are managed separately from infrastructure state. They need individual MFA enrollment and a project access policy before they can operate the environment. The EC2 role is for Systems Manager on the hosts and is not a human identity.

## Lab operation

The default Free-plan shape is c7i-flex.large in ap-southeast-2. A healthy monthly cost budget with a USD 25 limit and actual alerts at USD 10 and USD 20 was created separately. Credits are excluded from alert calculations.

Terraform output hosts supplies the three instance IDs and private addresses. Open a Systems Manager port forwarding session to port 8080 on the automation host for Jenkins. The Jenkins controller listens on that host's loopback address. Use the automation bootstrap script for Docker and Jenkins, and run the K3s Systems Manager bootstrap on the server before the worker.

The K3s join token is provisioned outside Terraform as an AWS Systems Manager SecureString at /devops-image-processing/k3s/join-token. The hosts read it at runtime and write it to a root-only file. Keep the plan, state, actual inventory credentials, and tokens out of Git.

Stop the project instances between lab sessions. Keep the state file and volumes for the next session. The cluster depends on these private addresses remaining attached to the same instances.
