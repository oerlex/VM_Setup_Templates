#!/bin/bash

#yum update -y &&
yum install -y epel-release &&
yum install -y wget &&
yum install -y unzip &&
yum install -y expect &&
yum install -y httpd &&
systemctl enable httpd &&
systemctl start httpd &&

# The default PHP version on CentOS 7 is PHP 5.4 and Nextcloud 14 requires PHP 7 or above, in this step we will install PHP version 7.
rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm &&
yum install -y yum-utils &&
yum-config-manager --enable remi-php70 &&
yum install -y php php-mysql php-pecl-zip php-xml php-mbstring php-gd php-fpm php-intl &&
systemctl restart php-fpm &&

# User input

echo Please insert your domain name...
read domainName

# Install MariaDB database server
touch /etc/yum.repos.d/MariaDB.repo &&

echo "[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1" >> /etc/yum.repos.d/MariaDB.repo &&

yum install -y MariaDB-server MariaDB-client &&
systemctl start mariadb &&
systemctl enable mariadb &&
sleep 2

# MYSQL/MARIADB SECURE INSTALLATION
# Found on https://github.com/bertvv

set -o errexit # abort on nonzero exitstatus&&
set -o nounset # abort on unbound variable

# Predicate that returns exit status 0 if the database root password
# is set, a nonzero exit status otherwise.
is_mysql_root_password_set() {
  ! mysqladmin --user=root status > /dev/null 2>&1
}

# Predicate that returns exit status 0 if the mysql(1) command is available,
# nonzero exit status otherwise.
is_mysql_command_available() {
  which mysql > /dev/null 2>&1
}

# Check if mysql is installed
if ! is_mysql_command_available; then
  echo "The MySQL/MariaDB client mysql(1) is not installed."
  exit 1
fi

# Check if the root password is already set
if is_mysql_root_password_set; then
  echo "Database root password already set"
  exit 0
fi

#Command line parsing
echo "Type in the new root password"
read -s db_root_password &&

mysql --user=root <<_EOF_
  UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  GRANT ALL on nextcloud.* to nextcloud@localhost identified by '${db_root_password}';
  FLUSH PRIVILEGES;
_EOF_
sleep 2

echo "MYSQL-Secure installation finished"

# Creation of a virtual host config file the domain to host Nextcloud.
touch /etc/httpd/conf.d/$domainName.conf
echo "<VirtualHost *:80>
ServerAdmin admin@$domainName
DocumentRoot /var/www/nextcloud
ServerName $domainName
ServerAlias www.$domainName
<Directory /var/www/html/nextcloud>
Options +FollowSymlinks
AllowOverride All
<IfModule mod_dav.c>
Dav off
</IfModule>
SetEnv HOME /var/www/nextcloud
SetEnv HTTP_HOME /var/www/nextcloud
</Directory>
ErrorLog /var/log/httpd/nextcloud-error_log
CustomLog /var/log/httpd/nextcloud-access_log common
</VirtualHost>" >> /etc/httpd/conf.d/$domainName.conf &&

wget https://download.nextcloud.com/server/releases/nextcloud-14.0.0.zip &&
unzip nextcloud-14.0.0.zip -d /var/www/ &&
mkdir /var/www/nextcloud/data &&
chown -R apache:apache /var/www/nextcloud &&

#SELinux should never be disabled but configured correctly
#Allows us to browse through the existing, default context policies, and create our own.
yum install -y policycoreutils-python &&


#Add file-context for everything under /var/www/nextcloud
semanage fcontext -a -t httpd_sys_content_t '/var/www/nextcloud(/.*)?' &&
#policy to assign the httpd_log_t context to the logging directories
semanage fcontext -a -t httpd_log_t '/var/log/httpd(/.*)?' &&
#policy to assign the httpd_cache_t context to our cache directories.
semanage fcontext -a -t httpd_cache_t 'var/cache/httpd(/.*)?' &&
#assign the httpd_sys_rw_content_t context to the configuration and apps directory,
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/nextcloud/config(/.*)?' &&
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/nextcloud/apps(/.*)?' &&

#semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/data(/.*)?' &&
#semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/config(/.*)?' &&
#semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/apps(/.*)?' &&
#semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.htaccess' &&
#semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/.user.ini' &&

#Apply the previously created SELinux policies
restorecon -Rv /var/www/nextcloud &&

#Firewall configurations to only allow web traffic
firewall-cmd --permanent --new-zone=publicweb &&
firewall-cmd --reload &&
firewall-cmd --zone=publicweb --permanent --add-service=http &&
firewall-cmd --zone=publicweb --permanent --add-service=https &&
firewall-cmd --zone=publicweb --permanent --add-service=ssh &&

##!!!CHANGE INTERFACE#####
firewall-cmd --zone=publicweb --change-interface=ens192 &&
systemctl restart network &&
systemctl reload firewalld &&
systemctl restart httpd
