package require AppDetecter
package require CommonUtil


::CommonUtil::spawnCommand yum install -y httpd
::CommonUtil::spawnCommand systemctl enable httpd


::CommonUtil::spawnCommand mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.origin

::CommonUtil::spawnCommand cp [file join $::baseDir apache httpd.conf] /etc/httpd/conf

set DocumentRoot [dict get $::ymlDict DocumentRoot]




#systemctl start httpd

#/etc/httpd/conf/httpd.conf:
#  ServerAdmin root@localhost
#  change root to /opt/www

#in out:



#In Directory:
#  RewriteEngine On
#  RewriteBase "/"
#  RewriteCond /opt/www/html/%{REQUEST_URI} !-f
#  RewriteRule ^(.+) "http://127.0.0.1:9008/$1" [P]
#or:
#<Location "/*">
#  ProxyPass "http://localhost:9008/"
#</Location>
