#!/bin/bash

echo "Starting Nexus Repository Manager installation..."

# Update package lists
sudo apt update || {
    echo "Failed to update package lists"
    exit 1
}

# Create directory if it doesn't exist
sudo mkdir -p /opt

# Install Java and net-tools
echo "Installing Java 8..."
sudo apt install openjdk-8-jre-headless net-tools -y || {
    echo "Failed to install Java"
    exit 1
}

# Verify Java installation
java -version || {
    echo "Java installation failed"
    exit 1
}

cd /opt

# Check if nexus directory exists and backup if it does
if [ -d "nexus" ]; then
    echo "Existing Nexus installation found. Creating backup..."
    timestamp=$(date +%Y%m%d_%H%M%S)
    sudo mv nexus "nexus_backup_${timestamp}"
fi

# Download Nexus Repository Manager with specific version
echo "Downloading Nexus..."
NEXUS_VERSION="3.69.0-02"
wget "https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz" || {
    echo "Failed to download Nexus"
    exit 1
}

# Extract the downloaded file
echo "Extracting Nexus..."
tar -zxvf "nexus-${NEXUS_VERSION}-unix.tar.gz"

# Rename the extracted folder
mv "nexus-${NEXUS_VERSION}" nexus

# Create nexus user - force recreation if needed
echo "Setting up nexus user..."
if getent passwd nexus > /dev/null; then
    echo "Removing existing nexus user..."
    sudo userdel nexus
fi

echo "Creating nexus user..."
sudo useradd -M -d /opt/nexus -s /bin/bash -r nexus || {
    echo "Failed to create nexus user"
    exit 1
}

# Create sonatype-work directory structure
echo "Setting up sonatype-work directory structure..."
sudo mkdir -p /opt/sonatype-work/nexus3/{log,tmp}

# Set ownership
echo "Setting correct permissions..."
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

# Configure run_as_user in nexus.rc
echo "Configuring nexus.rc..."
echo 'run_as_user="nexus"' | sudo tee /opt/nexus/bin/nexus.rc > /dev/null

# Create symbolic link
sudo ln -sf /opt/nexus/bin/nexus /etc/init.d/nexus

# Clean up downloaded archive
rm "nexus-${NEXUS_VERSION}-unix.tar.gz"

# Configure system limits for nexus user
echo "Configuring system limits for nexus user..."
sudo tee -a /etc/security/limits.conf > /dev/null << EOF
nexus - nofile 65536
nexus - nproc  32768
EOF

# Start Nexus
echo "Starting Nexus service..."
sudo /opt/nexus/bin/nexus start

# Wait for service to start
echo "Waiting for Nexus to start... (this may take a few minutes)"
sleep 60

# Check if service is running
if netstat -tlpn | grep 8081 > /dev/null; then
    echo "Nexus Repository Manager has been successfully installed and is running on port 8081"
    echo "You can access it at http://localhost:8081"
    echo "The initial admin password can be found in /opt/sonatype-work/nexus3/admin.password"
else
    echo "Nexus installation completed but service may not be running."
    echo "Please check logs at /opt/nexus/log/nexus.log"
fi
