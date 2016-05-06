package require AppDetecter
package require CommonUtil


::CommonUtil::spawnCommand yum install -y httpd
::CommonUtil::spawnCommand systemctl enable httpd

set conf /etc/httpd/conf/httpd.conf

if {! [file exists "${conf}.origin"]} {
    ::CommonUtil::spawnCommand cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.origin
}

set configConf [dict get $::ymlDict httpdConf]

::CommonUtil::spawnCommand cp [file join $::baseDir apache $configConf] $conf

::CommonUtil::spawnCommand systemctl start httpd


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
