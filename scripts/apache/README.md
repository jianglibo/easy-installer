## Usage

tclsh easy-installer.tcl --host=192.168.33.50 apache install

LogLevel alert rewrite:trace3

RewriteRule ^index.html$ "http://127.0.0.1:9008/" [P]

RewriteCond /mount/mysqlmirror/%{REQUEST_URI} !-f

RewriteCond %{REQUEST_FILENAME} !-f

RewriteRule ^(.+) "http://127.0.0.1:9008/$1" [P]
