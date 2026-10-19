#!/bin/bash
# Runs as root via cloud-init on Ubuntu 22.04. Log: /var/log/sonarqube-install.log
exec > >(tee -a /var/log/sonarqube-install.log) 2>&1
set -euxo pipefail

SONAR_VERSION="25.1.0.102122"
DB_NAME="sonarqube"
DB_USER="sonar"
DB_PASS="Sonar_$(openssl rand -hex 8)"
INSTALL_DIR="/opt/sonarqube"
URL="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"

export DEBIAN_FRONTEND=noninteractive
cd /tmp

# Wait for first-boot apt activity to finish
cloud-init status --wait || true

# Kernel and user limits
cat > /etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl -w vm.max_map_count=524288 fs.file-max=131072

cat > /etc/security/limits.d/99-sonarqube.conf <<'EOF'
sonar   -   nofile   131072
sonar   -   nproc    8192
EOF

# Packages
apt-get -o DPkg::Lock::Timeout=300 update -y
apt-get -o DPkg::Lock::Timeout=300 install -y openjdk-17-jdk postgresql postgresql-contrib unzip curl openssl

# PostgreSQL
systemctl enable --now postgresql
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE USER ${DB_USER};"
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASS}';"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

# SonarQube (retry the download a few times)
curl -fL --retry 5 --retry-delay 10 -o "sonarqube-${SONAR_VERSION}.zip" "$URL"
id sonar &>/dev/null || useradd -r -c "SonarQube user" -d "$INSTALL_DIR" -s /bin/false sonar
rm -rf "$INSTALL_DIR" "/opt/sonarqube-${SONAR_VERSION}"
unzip -q -o "sonarqube-${SONAR_VERSION}.zip" -d /opt/
mv "/opt/sonarqube-${SONAR_VERSION}" "$INSTALL_DIR"

cat >> "$INSTALL_DIR/conf/sonar.properties" <<EOF

sonar.jdbc.username=${DB_USER}
sonar.jdbc.password=${DB_PASS}
sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF
chown -R sonar:sonar "$INSTALL_DIR"
chmod 640 "$INSTALL_DIR/conf/sonar.properties"

# Keep the DB password readable by root only
echo "${DB_PASS}" > /root/sonarqube-db-password.txt
chmod 600 /root/sonarqube-db-password.txt

# systemd service
cat > /etc/systemd/system/sonarqube.service <<'EOF'
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=on-failure
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sonarqube

# Wait for readiness (up to ~5 min) and log the result
for i in $(seq 1 60); do
  if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    echo "SonarQube is UP"; exit 0
  fi
  sleep 5
done
echo "SonarQube did not report UP in time; check /opt/sonarqube/logs/"
exit 1