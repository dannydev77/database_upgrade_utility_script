#!/bin/bash

# ==========================================================================
# Script Name:     database_upgrade.sh
# Description:     This script automates the process of upgrading MariaDB on CyberPanel server.
# Author:          Dan Kibera
# Email:           info@lintsawa.com
# License:         MIT License
# Version:         1.1
# Date:            3rd Aug, 2024.
# ==========================================================================

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to handle errors
handle_error() {
    echo "=========================================================="
    echo "Error: $1"
    echo "Exiting..."
    echo "=========================================================="
    exit 1
}

# Check for root privileges
echo "=========================================================="
echo "Checking for root privilege ............."
echo "=========================================================="
if [ "$EUID" -ne 0 ]; then
    handle_error "This script must be run as root."
fi
echo "=========================================================="
echo "You are running as root....Proceeding...."
echo "=========================================================="

# Check OS version
echo "=========================================================="
echo "Checking OS version..."
echo "=========================================================="
. /etc/os-release
if [ "$NAME" = "Ubuntu" ] && [ "${VERSION_ID//.}" -ge 2004 ]; then
    echo "=========================================================="
    echo "OS is $NAME $VERSION_ID, compatible for upgrade."
    echo "=========================================================="
else
    handle_error "This script is compatible only with Ubuntu 20.04 or higher."
fi

# Check for control panels
echo "=========================================================="
echo "Checking for installed control panels..."
echo "=========================================================="

# Detect CyberPanel
if [ -f /usr/local/CyberCP/CyberCP/settings.py ]; then
    echo "CyberPanel detected."
else
    handle_error "CyberPanel not detected. This script can only be run on servers with CyberPanel."
fi

# Detect other common control panels
PANEL_DETECTED=false

# Check for cPanel
if [ -d /usr/local/cpanel ]; then
    echo "cPanel detected."
    PANEL_DETECTED=true
fi

# Check for Plesk
if [ -d /usr/local/psa ]; then
    echo "Plesk detected."
    PANEL_DETECTED=true
fi

# Check for CloudPanel
if [ -d /opt/cloudpanel ]; then
    echo "CloudPanel detected."
    PANEL_DETECTED=true
fi

# Check for other control panels
# Add checks for any additional control panels as needed

if [ "$PANEL_DETECTED" = true ]; then
    handle_error "Another control panel detected. This script is only supported on CyberPanel."
fi

# Confirm current MariaDB version
echo "=========================================================="
echo "Confirming current MariaDB version..."
echo "=========================================================="
CURRENT_VERSION=$(mariadb --version | grep -oP '\d+\.\d+\.\d+')
if [ -z "$CURRENT_VERSION" ]; then
    handle_error "Unable to determine the current MariaDB version."
fi
echo "Current MariaDB version: $CURRENT_VERSION"

# Check if upgrade from 10.3 to 10.6 is supported
echo "=========================================================="
echo "Checking if upgrade from $CURRENT_VERSION to 10.6 is supported..."
echo "=========================================================="
if [ "$(echo "$CURRENT_VERSION" | grep -o '^10\.3')" ]; then
    echo "=========================================================="
    echo "Upgrade path from $CURRENT_VERSION to 10.6 is supported."
    echo "=========================================================="
else
    handle_error "Upgrade path from $CURRENT_VERSION to 10.6 may not be supported. Please check MariaDB documentation."
fi

# Check if any databases exist
echo "=========================================================="
echo "Checking for existing databases..."
echo "=========================================================="
DB_COUNT=$(mariadb -N -e 'SHOW DATABASES;' | wc -l)
if [ "$DB_COUNT" -eq 0 ]; then
    handle_error "No databases found."
else
    echo "=========================================================="
    echo "Found $DB_COUNT databases. Proceeding with upgrade."
    echo "=========================================================="
fi

# Check for deprecated features
echo "=========================================================="
echo "Checking for deprecated features in MariaDB configuration..."
echo "=========================================================="
DEPRECATED_FEATURES=$(mariadb --print-defaults | grep -i "deprecated")
if [ -n "$DEPRECATED_FEATURES" ]; then
    echo "=========================================================="
    echo "Deprecated features detected:"
    echo "$DEPRECATED_FEATURES"
    handle_error "Please review and remove deprecated features before proceeding."
else
    echo "=========================================================="
    echo "No deprecated features found."
    echo "=========================================================="
fi

# Backup all databases
BACKUP_DIR="/home/dbs/databases"
echo "=========================================================="
echo "Backing up all databases to $BACKUP_DIR"
echo "=========================================================="
mkdir -p "$BACKUP_DIR"
mariadb -N -e 'show databases' | while read -r dbname; do
  echo "Backup in progress $dbname......"
  if ! mysqldump --complete-insert --routines --triggers --single-transaction "$dbname" > "$BACKUP_DIR/$dbname.sql"; then
    handle_error "Backup failed for database $dbname."
  fi
done
echo "=========================================================="
echo "Backup job completed."
echo "=========================================================="

# Retrieve MariaDB root password
echo "=========================================================="
echo "Retrieving MariaDB root password..."
echo "=========================================================="
MYSQL_ROOT_PASSWORD=$(cat /etc/cyberpanel/mysqlPassword)
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    handle_error "MariaDB root password not found."
fi
echo "Password retrieved."

# Prepare for shutdown
echo "=========================================================="
echo "Configuring MariaDB for proper shutdown..."
echo "=========================================================="
if ! mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "SET GLOBAL innodb_fast_shutdown = 1;"; then
    handle_error "Failed to set innodb_fast_shutdown."
fi
if ! mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "XA RECOVER;"; then
    handle_error "Failed to execute XA RECOVER."
fi
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
  handle_error "Failed to stop MariaDB server."
fi

echo "=========================================================="
echo "Removing old MariaDB packages..."
echo "=========================================================="
apt list --installed | grep -i -E "mariadb|galera"
apt remove "*mariadb*" "galera*" -y
if apt list --installed | grep -i -E "mariadb|galera"; then
  handle_error "Some MariaDB packages are still present. Manual intervention required."
else
  echo "=========================================================="
  echo "Old MariaDB packages removed successfully."
  echo "=========================================================="
fi

# Install the new MariaDB version
echo "=========================================================="
echo "Installing MariaDB 10.6....."
echo "=========================================================="
if ! curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.6"; then
    handle_error "Failed to setup MariaDB repository."
fi
apt update
if ! apt install mariadb-server libmariadb-dev -y; then
    handle_error "Failed to install MariaDB 10.6."
fi
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
  handle_error "Failed to start MariaDB server."
fi

# Upgrade the database schema
echo "=========================================================="
echo "Running mariadb_upgrade..."
echo "=========================================================="
start_time=$(date +%s)
if ! mariadb-upgrade -u root -p"$MYSQL_ROOT_PASSWORD"; then
    handle_error "Upgrade encountered issues. Please check the logs."
fi
echo "=========================================================="
echo "Upgrade completed successfully."
echo "=========================================================="

# Force the upgrade
echo "=========================================================="
echo "Forcing upgrade with mariadb-upgrade --force..."
echo "=========================================================="
if ! mariadb-upgrade --force; then
    handle_error "Forced upgrade encountered issues. Please check the logs."
fi
echo "=========================================================="
echo "Forced upgrade completed successfully."
echo "=========================================================="

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
