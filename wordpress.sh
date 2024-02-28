#!/usr/bin/bash
# ----------,,,
# AUTH: Robert Gates
# DESC: Create a generic script that can be pulled 
#       and create a Boilerplate wordpress site
# ----------,,,
# Virtualization Assumptions:
#
# -Created Virtual Machine on Proxmox Virtual Environment 7.2-3
# -General
#   Chose VM ID and NAME in accordance with Local Procedures
# -OS
#   Select ISO image file:
#       ubuntu-22.04.2-live-server-amd64.iso
# -System
#   Default settings
# -Disks
#   Default settings
# -CPU
#   Set Cores:
#       2
# -Memory
#   Set Memory:
#       8192
# -Network
#   Default settings
# -Confirm
#   Check box (Start after created)
# ----------,,,
# OS Assumptions:
#
# [Step]
#   [selection]
#       [deviation]
#           [Option/Note]
#
# Language Select
#   English
# Installer update
#   Continue without updating
# Keyboard configuration
#   Done
# Type of install
#   Done
# Network Connections
#           Note: This section will be in accordance with Local Procedure.
#               The following is a [suggested] guideline for manual config
#       select interface (example: "[ eno1   eth   -    > ]"")
#       select "Edit IPv4"
#       select IPv4 Method "Manual"
#       Subnet:         [192.168.1.0/24]
#       Address:        [192.168.1.###]
#           Note: Select an address not in use
#       Gateway:        [192.168.1.1]
#           Note: this ip is typically your router (DHCP/DNS Server)
#       Nameservers:    [8.8.8.8]
#           Note: Google DNS Server IP (8.8.8.8)
#       Search domains: 
#           Note: intentionally left empty
#       select "save"
#
#           option: configure static IP via router (DHCP server)
#   Done
# Configure Proxy
#   Done
# Configure Ubuntu archive mirror
#   Done
# Guided storaghe configuration
#   Done
# Storage Configuration
#   Done
# Confirm destructive action
#   Continue
# Profile setup
#           Note: This section will be in accordance with Local Procedure.
#               The following is a [suggested] guideline
#       Your name:              [first last]
#       Your server's name:     [server role]
#       Pick a username:        [consistant with other usernames]
#       Choose a password:      [strong password]
#       Confirm your password:  [same strong password]
# Upgrade to Ubuntu Pro
#   Continue
# SSH Setup
#       Press [Spacebar] to enable ("[X] Install OpenSSH server")
#   Done
# Featured Server Snaps
#   Done
# Install complete!
#           Note: please wait for system configuration
#   Reboot Now
# Ubuntu Login
#   Enter username
#   Enter password
# ----------,,,
# YOU ARE HERE!
# SCRIPT START

main() {
    standard_update
    install_packages
    service_check apache2
    service_check mysql
    mariadb_setup
    mysql_sec_install
    wordpress_setup
    apache_config
    service_check apache2
    service_check mysql
    echo -e "\nScript Complete, please visit your host ip address to install"
}

standard_update() {
    apt update && apt -y upgrade
}

# TODO: figure out how to insert multiple responses better than echo 'y'
install_packages() {
    apt -y install \
    apache2 \
    mariadb-server \
    libapache2-mod-php \
    php-curl \
    php-gd \
    php-intl \
    php-imagick \
    php-mbstring \
    php-mysql \
    php-soap \
    php-xml \
    php-xmlrpc \
    php-zip 
}

service_check() {
    echo -e "\nChecking $1"
    if systemctl is-active --quiet $1;then
        echo -e "\t$1 is active"
    else
        echo -e "\t$1 is inactive"
    fi
}

# TODO: make a better condition statement
#   preferebly one that checks the actual database and user
mariadb_setup() {
    echo -e "\n\nConfiguring MariaDB MySQL Database"
    echo -e "--------------------------------------"
    if [ -f /tmp/DB_complete ];then
        echo -e "\tMariaDB MySQL Database already configured"
        mariadb -e  "SHOW DATABASES;
                    SELECT user, host FROM mysql.user;"
    else
        echo -e "\tEnter password for wp_local user"
        read sql_local
        echo -e "\tDo you wish to enable remote access? [y/N]"
        read answer
        if [[ $answer == 'y']]||[[ $answer == 'Y']];then
            echo -e "\tEnter host ip/FQDN for wp_remote user"
            read remote_ip
            echo -e "\tEnter password for wp_remote user"
            read sql_remote
        fi
        mariadb -e  "CREATE DATABASE $(hostname)_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
                    GRANT ALL PRIVILEGES ON $(hostname)_db.* TO wp_local@localhost IDENTIFIED BY '$sql_local';"
        if [[ $answer == 'y']]||[[ $answer == 'Y']];then
            mariadb -e  "GRANT ALL PRIVILEGES ON $(hostname)_db.* TO wp_remote@$remote_ip IDENTIFIED BY '$sql_remote';"
        fi
        mariadb -e  "SHOW DATABASES;
                    SELECT user, host FROM mysql.user;
                    FLUSH PRIVILEGES;"
        echo -e "\tCreated $(hostname)_db"
        echo -e "\tCreated 'wp_local@localhost' database custodian"
        if [[ $answer == 'y']]||[[ $answer == 'Y']];then
            echo -e "\tCreated 'wp_remote@$remote_ip' database custodian"
            echo -e "\tConfiguring Bind-Address Variable"
            sed -i 's/127.0.0.1/$remote_ip' /etc/mysql/mariadb.conf.d/50-server.cnf
        fi
        touch /tmp/.DB_complete
    fi
}

# TODO: figure out how to insert multiple responses better than echo -e 'y'
mysql_sec_install() {
    echo -e "\n\nEstablishing MariaDB Secure Configuration"
    echo -e "---------------------------------------------"
    echo -e "This script assumes that this is first time setup"
    echo 
    echo "Please enter a new MariaDB root password"
    read root_pass
    mariadb -e "UPDATE mysql.user SET Password=PASSWORD('$root_pass') WHERE User='root';
                DELETE FROM mysql.user WHERE User='';
                DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
                DROP DATABASE test;
                DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'
                FLUSH PRIVILEGES;"
    echo "Basic Secure Configuration has been established"
}

wordpress_setup() {
    echo -e "\n\nStarting Wordpress setup"
    echo -e "----------------------------"
    if [ -d /var/www/wordpress ];then
        echo -e "\tWordpress is already present at '/var/www/wordpress'"
    else
        echo -e "\tStarting Download"
        cd /opt
        wget https://wordpress.org/latest.tar.gz
        echo -e "\tDecompressing tar.gz"
        tar -xvzf latest.tar.gz
        mv wordpress/ /var/www/html/wordpress/
        chown -R www-data:www-data /var/www/wordpress
        echo -e "\tWordpress files can be found at /var/www/wordpress"
    fi

}


apache_config() {
    echo -e "\n\nStarting Apache2 setup"
    echo -e "--------------------------"
    if [ -f /etc/apache2/sites-available/wordpress.conf ];then
        echo -e "\t/etc/apache2/sites-available/wordpress.conf is already present"
    else    
        echo -e "\tConfiguring /etc/apache2/sites-available/wordpress.conf"
        echo -e "\
<VirtualHost *:80>
    DocumentRoot /var/www/wordpress
    <Directory /var/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /var/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>" > /etc/apache2/sites-available/wordpress.conf
        echo -e "\tApache2 Enable Site: wordpress.conf"
        a2ensite wordpress.conf
        if [ -f /etc/apache2/sites-available/000-default.conf ];then
            echo -e "\tApache2 Disable Site: 000-default.conf"
            a2dissite 000-default.conf
        fi
        echo -e "\tApache2 Enable Mod: rewrite"
        a2enmod rewrite
        echo -e "\tRestarting apache2"
        systemctl restart apache2
        echo -e "\tApache2 configured"
    fi
}

main