#!/bin/bash

# ==========================================================================
# Script Name:     database_upgrade.sh
# Description:     This script automates the process of upgrading MariaDB on CyberPanel server.
# Author:          Dan Kibera
# Email:           info@lintsawa.com
# License:         MIT License
# Version:         1.0
# Date:            2nd Aug, 2024.
# ==========================================================================



# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for root privileges
echo "=========================================================="
echo "Checking for root privilege .................................................................................."
echo "=========================================================="
if [[ $EUID -ne 0 ]]; then
   echo "=========================================================="
   echo "This script must be run as root. Exiting..."
   echo "=========================================================="
   exit 1
fi
echo "=========================================================="
echo "You are running as root....Proceeding...."
echo "=========================================================="

# Check OS version
echo "=========================================================="
echo "Checking OS version..."
echo "=========================================================="
. /etc/os-release
if [[ "$NAME" == "Ubuntu" && "${VERSION_ID//.}" -ge 2004 ]]; then
    echo "=========================================================="
    echo "OS is $NAME $VERSION_ID, compatible for upgrade."
    echo "=========================================================="
else
    echo "=========================================================="
    echo "This script is compatible only with Ubuntu 20.04 or higher. Exiting..."
    echo "=========================================================="
    exit 1
fi

# Check for control panels
echo "=========================================================="
echo "Checking for installed control panels..."
echo "=========================================================="

# Detect CyberPanel
if [[ -f /usr/local/CyberCP/CyberCP/settings.py ]]; then
    echo "CyberPanel detected."
else
    echo "=========================================================="
    echo "CyberPanel not detected. This script can only be run on servers with CyberPanel."
    echo "=========================================================="
    exit 1
fi

# Detect other common control panels
PANEL_DETECTED=false

# Check for cPanel
if [[ -d /usr/local/cpanel ]]; then
    echo "cPanel detected."
    PANEL_DETECTED=true
fi

# Check for Plesk
if [[ -d /usr/local/psa ]]; then
    echo "Plesk detected."
    PANEL_DETECTED=true
fi

# Check for CloudPanel
if [[ -d /opt/cloudpanel ]]; then
    echo "CloudPanel detected."
    PANEL_DETECTED=true
fi

# Check for other control panels
# Add checks for any additional control panels as needed

if [ "$PANEL_DETECTED" = true ]; then
    echo "=========================================================="
    echo "Another control panel detected. This script is only supported on CyberPanel. Exiting..."
    echo "=========================================================="
    exit 1
fi

# Confirm current MariaDB version
echo "=========================================================="
echo "Confirming current MariaDB version..."
echo "=========================================================="
CURRENT_VERSION=$(mariadb --version | grep -oP '\d+\.\d+\.\d+')
echo "Current MariaDB version: $CURRENT_VERSION"

# Check if upgrade from 10.3 to 10.6 is supported
echo "=========================================================="
echo "Checking if upgrade from $CURRENT_VERSION to 10.6 is supported..."
echo "=========================================================="
if [[ "$CURRENT_VERSION" =~ ^10\.3 ]]; then
    echo "=========================================================="
    echo "Upgrade path from $CURRENT_VERSION to 10.6 is supported."
    echo "=========================================================="
else
    echo "=========================================================="
    echo "Upgrade path from $CURRENT_VERSION to 10.6 may not be supported. Please check MariaDB documentation."
    echo "Exiting..."
    echo "=========================================================="
    exit 1
fi

# Check for sufficient disk space
echo "=========================================================="
echo "Checking for sufficient disk space..."
echo "=========================================================="
REQUIRED_SPACE_GB=5  # Estimate required space in GB
AVAILABLE_SPACE_GB=$(df / | awk 'NR==2 {print $4 / 1024 / 1024}')
if (( $(echo "$AVAILABLE_SPACE_GB >= $REQUIRED_SPACE_GB" | bc -l) )); then
    echo "=========================================================="
    echo "Sufficient disk space available: $AVAILABLE_SPACE_GB GB"
    echo "=========================================================="
else
    echo "=========================================================="
    echo "Insufficient disk space: $AVAILABLE_SPACE_GB GB available, $REQUIRED_SPACE_GB GB required. Exiting..."
    echo "=========================================================="
    exit 1
fi

# Backup all databases
BACKUP_DIR="/home/dbs/databases"
echo "=========================================================="
echo "Backing up all databases to $BACKUP_DIR"
echo "=========================================================="
mkdir -p "$BACKUP_DIR"
mysql -N -e 'show databases' | while read dbname; do
  echo "Backing up $dbname..."
  mysqldump --complete-insert --routines --triggers --single-transaction "$dbname" > "$BACKUP_DIR/$dbname.sql"
done
echo "=========================================================="
echo "Backup completed."
echo "=========================================================="

# Retrieve MariaDB root password
echo "=========================================================="
echo "Retrieving MariaDB root password..."
echo "=========================================================="
MYSQL_ROOT_PASSWORD=$(cat /etc/cyberpanel/mysqlPassword)
if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    echo "=========================================================="
    echo "MariaDB root password not found. Exiting..."
    echo "=========================================================="
    exit 1
fi
echo "Password retrieved."

# Prepare for shutdown
echo "=========================================================="
echo "Configuring MariaDB for proper shutdown..."
echo "=========================================================="
mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "SET GLOBAL innodb_fast_shutdown = 1;"
mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "XA RECOVER;"
echo "=========================================================="
echo "MariaDB configured for shutdown."
echo "=========================================================="

# Stop and remove the old MariaDB version
echo "=========================================================="
echo "Stopping MariaDB service..."
echo "=========================================================="
systemctl stop mariadb
if systemctl status mariadb | grep "inactive (dead)"; then
  echo "=========================================================="
  echo "MariaDB server has been stopped successfully."
  echo "=========================================================="
else
  echo "=========================================================="
  echo "Failed to stop MariaDB server. Exiting..."
  echo "=========================================================="
  exit 1
fi

echo "=========================================================="
echo "Removing old MariaDB packages..."
echo "=========================================================="
apt list --installed | grep -i -E "mariadb|galera"
apt remove "*mariadb*" "galera*" -y
if apt list --installed | grep -i -E "mariadb|galera"; then
  echo "=========================================================="
  echo "Some MariaDB packages are still present. Manual intervention required."
  echo "=========================================================="
else
  echo "=========================================================="
  echo "Old MariaDB packages removed successfully."
  echo "=========================================================="
fi

# Install the new MariaDB version
echo "=========================================================="
echo "Installing MariaDB 10.6..."
echo "=========================================================="
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.6"
apt update
apt install mariadb-server libmariadb-dev -y
echo "=========================================================="
echo "MariaDB 10.6 installed."
echo "=========================================================="

# Start the new MariaDB service
echo "=========================================================="
echo "Starting MariaDB service..."
echo "=========================================================="
systemctl enable mariadb
systemctl start mariadb
if systemctl status mariadb | grep "active (running)"; then
  echo "=========================================================="
  echo "MariaDB server started successfully."
  echo "=========================================================="
else
  echo "=========================================================="
  echo "Failed to start MariaDB server. Exiting..."
  echo "=========================================================="
  exit 1
fi

# Upgrade the database schema
echo "=========================================================="
echo "Running mariadb_upgrade..."
echo "=========================================================="
start_time=$(date +%s)
mariadb-upgrade -u root -p"$MYSQL_ROOT_PASSWORD"
if [ $? -eq 0 ]; then
  echo "=========================================================="
  echo "Upgrade completed successfully."
  echo "=========================================================="
else
  echo "=========================================================="
  echo "Upgrade encountered issues. Please check the logs."
  echo "=========================================================="
  exit 1
fi

# Force the upgrade
echo "=========================================================="
echo "Forcing upgrade with mariadb-upgrade --force..."
echo "=========================================================="
mariadb-upgrade --force
if [ $? -eq 0 ]; then
  echo "=========================================================="
  echo "Forced upgrade completed successfully."
  echo "=========================================================="
else
  echo "=========================================================="
  echo "Forced upgrade encountered issues. Please check the logs."
  echo "=========================================================="
  exit 1
fi

# Final checks
echo "=========================================================="
echo "Checking MariaDB version..."
echo "=========================================================="
mariadb --version
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "=========================================================="
echo "MariaDB upgrade process completed in $elapsed_time seconds. Please verify all databases are operational."
echo "=========================================================="
