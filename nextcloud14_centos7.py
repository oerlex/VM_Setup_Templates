#Live documentation that might someday result in an installation script. So far its more a collection of commands I have used installing and configuring
# Nextcloud 14 on Centos7

system("yum update")
system("yum install -y epel-release")
system("yum install -y wget")
system("yum install -y unzip")

webserver = input("Do you want to run (1)Apache or (2)Nginx ?")

if webserver != "1" | "2":
    print("Only option 1 or 2 valid")

if webserver == 2:
    system("yum install -y httpd")
    system("systemctl enable httpd")
    system("systemctl start httpd")
else:
    #do nginx stuff

# The default PHP version on CentOS 7 is PHP 5.4 and Nextcloud 14 requires PHP 7 or above, in this step we will install PHP version 7.
def installphp7():
    system("rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm")
    system("yum install -y yum-utils")
    system("yum-config-manager --enable remi-php70")
    system("yum install -y php php-mysql php-pecl-zip php-xml php-mbstring php-gd php-fpm php-intl")
    system("systemctl restart php-fpm")

# Install MariaDB database server
def installmariadb():
    file = open("/etc/yum.repos.d/MariaDB.repo", "w")
    file.write("[mariadb]")
    file.write("name = MariaDB")
    file.write("baseurl = http://yum.mariadb.org/10.2/centos7-amd64")
    file.write("gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB")
    file.write("gpgcheck=1")
    file.close()
    system("yum install -y MariaDB-server MariaDB-client")
    system("systemctl start mariadb \n systemctl enable mariadb \n systemctl status mariadb")
    system("mysql_secure_installation")
    system('mysql -uroot -p -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci')
    grantpw = input("Provide the identified pw used for grantin permissions...")
    system('mysql -uroot -p -e "GRANT ALL on nextcloud.* to nextcloud@localhost identified by '+grantpw+'"')
    system('mysql -uroot -p -e "FLUSH privileges')


def configureWebServer(domainname):

    # Creation of a virtual host config file the domain to host Nextcloud.
    with open(filename, '/etc/httpd/conf.d/'+domainname+'.conf') as out:
        out.write("<VirtualHost *:80> \n \nServerAdmin admin@yourdomain.com \nDocumentRoot /var/www/nextcloud \nServerName yourdomain.com \nServerAlias www.yourdomain.com"+
        "\n \n <Directory /var/www/html/nextcloud> \nOptions +FollowSymlinks \nAllowOverride All \n<IfModule mod_dav.c> \nDav off\n</IfModule>"+
        "\n SetEnv HOME /var/www/nextcloud \n SetEnv HTTP_HOME /var/www/nextcloud \n</Directory> \nErrorLog /var/log/httpd/nextcloud-error_log \nCustomLog /var/log/httpd/nextcloud-access_log common\n</VirtualHost>")

        system("wget https://github.com/nextcloud/server/archive/v14.0.3.zip")
        system("unzip server-14.0.3.zip -d /var/www/")
        system("mkdir /var/www/nextcloud/data")
        system("chown -R apache:apache /var/www/nextcloud")


#Creation and deployment of a SSL certificate to be used on the webserver
def certificateDeployment():
    system("yum install certbot-nginx certbot-apache")

# Setting the usual Linux permissions for apache
def apachePermissions():
    system("chmod -R 750 /var/www/nextcloud/")
    #all new files and subdirectories created within the current directory inherit the group ID of the directory,
    system("chmod g+s /var/www/nextcloud/")
    #nextcloud requires RWX on the config directory
    system("chmod -R 770 /var/www/nextcloud/config/")
    system("chmod -R 770 /var/www/nextcloud/apps/")

#SELinux should never be disabled but configured correctly
def seLinuxPolicies():
    #Allows us to browse through the existing, default context policies, and create our own.
    system("yum install -y policycoreutils-python")

    #Add file-context for everything under /var/www/nextcloud
    system("semanage fcontext -a -t httpd_sys_content_t ""/var/www/nextcloud(/.*)?""")
    #policy to assign the httpd_log_t context to the logging directories
    system("semanage fcontext -a -t httpd_log_t ""/var/log/httpd(/.*)?""")
    #policy to assign the httpd_cache_t context to our cache directories.
    system("semanage fcontext -a -t httpd_cache_t ""/var/cache/httpd(/.*)?""")
    #assign the httpd_sys_rw_content_t context to the configuration and apps directory,
    system("semanage fcontext -a -t httpd_sys_rw_content_t ""/var/www/nextcloud/config(/.*)?""")
    system("semanage fcontext -a -t httpd_sys_rw_content_t ""/var/www/nextcloud/apps(/.*)?""")

    #Apply the previously created SELinux policies
    system("restorecon -Rv /var/www/nextcloud")

def firewalldConfigurations():

#Other stuff to take care of:
# Iptables rules / for testing flush iptables using: iptables -F
# add a trusted domain in /var/www/xyz/config/config.php

installphp7()
installmariadb()
configureWebServer("localhost")
apachePermissions()
seLinuxPolicies()
