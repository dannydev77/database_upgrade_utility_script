# MariaDB Upgrade Script

## Description

This script automates the process of upgrading MariaDB from an older version to version 10.6 on a server running Ubuntu. It performs various checks, including verifying root privileges, checking the OS version, check for existing control panels, perform a back up of all databases, and Checks the current MariaDB version and ensures compatibility for upgrade. If not compatible the the script will not be executed. 

## Usage

1. **Download and Execute the Script**

   You can download and run the script using the following command:

   ```bash
   bash <(curl -s https://raw.githubusercontent.com/dannydev77/database_upgrade_utility_script/main/database_upgrade.sh || wget -qO- https://raw.githubusercontent.com/dannydev77/database_upgrade_utility_script/main/database_upgrade.sh)


The script will at some point for input. 
Enter optin 'N' and it will proceed.

# Script Features and Details

## Features

- **Root Privileges Check**: Ensures the script is run as the root user.
- **OS Version Check**: Verifies that the operating system is Ubuntu 20.04 or higher.
- **Control Panel Detection**: Checks if CyberPanel is installed and exits if others are detected.
- **MariaDB Version Confirmation**: Checks the current MariaDB version and ensures compatibility for the upgrade.
- **Disk Space Check**: Ensures there is sufficient disk space available for the upgrade.
- **Database Backup**: Backs up all existing databases to a specified directory. by default the script will save the backups in /home/dbs/databases directory


- **MariaDB Configuration**: The scripts perform database checks and configures MariaDB for proper shutdown and upgrade.

## Requirements

- **Operating System**: Ubuntu 20.04 or higher.
- **Root Privileges**: Must be executed as root.
- **Disk Space**: At least 5 GB of free disk space.

## License

MIT License

## Contact

- **Author**: Dan Kibera
- **Email**: info@lintsawa.com

## Notes

- Ensure to review and understand the script before executing it.
- Backup your databases and critical data before running the script. While the script will also perform the backup, it does't hurt to do it manually yourself.
- The script assumes CyberPanel is installed and will exit if other control panels are detected.


## Additional Information 
For more detailed information about upgrading MariaDB, please refer to the official MariaDB documentation:

- **MariaDB Upgrade Documentation**: [MariaDB Upgrade Documentation](https://mariadb.com/docs/server/service-management/upgrades/community-server/release-series-cs10-6/)


