package require JavaInstaller

::JavaInstaller::install

yum install -y httpd
systemctl start httpd

/etc/httpd/conf/httpd.conf:
  ServerAdmin root@localhost
  change root to /opt/www

in out:



In Directory:
  RewriteEngine On
  RewriteBase "/"
  RewriteCond /opt/www/html/%{REQUEST_URI} !-f
  RewriteRule ^(.+) "http://127.0.0.1:9008/$1" [P]
or:
<Location "/*">
  ProxyPass "http://localhost:9008/"
</Location>
