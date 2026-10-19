#!/bin/bash
# Jenkins + Terraform on Ubuntu 22.04. Runs as root via EC2 user_data.
# Output goes to /var/log/cloud-init-output.log
set -x
export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -o DPkg::Lock::Timeout=300"

# 1. Base packages
$APT update
$APT install wget gnupg2 software-properties-common apt-transport-https ca-certificates curl lsb-release

# 2. Java (Jenkins needs it)
$APT install fontconfig openjdk-21-jre || $APT install fontconfig openjdk-17-jre
java -version

# 3. Terraform repository (HashiCorp)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

# 4. Jenkins repository (stable line, 2026 signing key)
mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# 5. Install both
$APT update
$APT install terraform jenkins

systemctl enable jenkins
systemctl start jenkins

# 6. Wait for Jenkins to create its first-time password (up to 5 minutes)
for i in $(seq 1 60); do
  [ -f /var/lib/jenkins/secrets/initialAdminPassword ] && break
  sleep 5
done

echo "Jenkins installed successfully."
echo "Jenkins initial admin password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
