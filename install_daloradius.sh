apt update
apt install -y apache2
a2dissite 000-default.conf
systemctl stop apache2
apt install -y mariadb-server
mysql_secure_installation
systemctl stop mariadb
apt install -y php libapache2-mod-php php-mysql php-zip php-mbstring php-cli php-common php-curl
apt install -y php-gd php-db php-mail php-mail-mime

apt install -y git
cd /var/www/
git clone https://github.com/lirantal/daloradius.git

cat <<EOF >/etc/apache2/ports.conf
Listen 80
Listen 8000

<IfModule ssl_module>
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

cat <<EOF >/etc/apache2/sites-available/operators.conf
<VirtualHost *:8000>
    ServerAdmin operators@localhost
    DocumentRoot /var/www/daloradius/app/operators

    <Directory /var/www/daloradius/app/operators>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    <Directory /var/www/daloradius>
        Require all denied
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/daloradius/operators/error.log
    CustomLog \${APACHE_LOG_DIR}/daloradius/operators/access.log combined
</VirtualHost>
EOF

cat <<EOF >/etc/apache2/sites-available/users.conf
<VirtualHost *:80>
    ServerAdmin users@localhost
    DocumentRoot /var/www/daloradius/app/users

    <Directory /var/www/daloradius/app/users>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    <Directory /var/www/daloradius>
        Require all denied
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/daloradius/users/error.log
    CustomLog \${APACHE_LOG_DIR}/daloradius/users/access.log combined
</VirtualHost>
EOF

mkdir -p /var/log/apache2/daloradius/operators
mkdir -p /var/log/apache2/daloradius/users

a2ensite users.conf operators.conf

systemctl enable mariadb
systemctl restart mariadb

mysql -u root -e "CREATE DATABASE raddb;"
mysql -u root -e "CREATE USER 'raduser'@'localhost' IDENTIFIED BY 'radpass';"
mysql -u root -e "GRANT ALL PRIVILEGES ON raddb.* TO 'raduser'@'localhost'"

mysql -u root raddb </var/www/daloradius/contrib/db/fr3-mysql-freeradius.sql
mysql -u root raddb </var/www/daloradius/contrib/db/mysql-daloradius.sql

cd /var/www/daloradius/app/common/includes/
cp daloradius.conf.php.sample daloradius.conf.php
chown www-data:www-data daloradius.conf.php

cd /var/www/daloradius/
mkdir var
mkdir var/log
mkdir var/backup
chown -R www-data:www-data var

systemctl enable apache2
systemctl restart apache2

apt install -y freeradius freeradius-mysql

sed -i 's/ipaddr = 127.0.0.1/ipaddr = 0.0.0.0\/0/g' /etc/freeradius/3.0/clients.conf
sed -i 's/dialect = "sqlite"/dialect = "mysql"/g' /etc/freeradius/3.0/mods-available/sql
sed -i 's/radius_db = "radius"/radius_db = "raddb"/g' /etc/freeradius/3.0/mods-available/sql
sed -i '157,160s/^#\{0,1\}\s*//' /etc/freeradius/3.0/mods-available/sql
sed -i '87,97s/^/#/' /etc/freeradius/3.0/mods-available/sql
sed -i 's/login = "radius"/login = "raduser"/g' /etc/freeradius/3.0/mods-available/sql
sed -i '61s/^/#/' /etc/freeradius/3.0/mods-available/sql
sed -i '62s/.*/driver = "rlm_sql_mysql"/' /etc/freeradius/3.0/mods-available/sql
ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
ln -s /etc/freeradius/3.0/mods-available/sqlcounter  /etc/freeradius/3.0/mods-enabled/sqlcounter 
ln -s /etc/freeradius/3.0/mods-available/sqlippool  /etc/freeradius/3.0/mods-enabled/sqlippool 
sudo sed -i '117s/$/\"/' /etc/freeradius/3.0/mods-config/sql/ippool/mysql/queries.conf
systemctl restart freeradius.service
