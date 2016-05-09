## install a master server:
* tclsh easy-installer.tcl --host=192.168.33.50 --profile=local-profile.secret.yml --mocklist=mocklist-local.txt mysql install
* tclsh easy-installer.tcl --host=192.168.33.50 --profile=local-profile.secret.yml --notRunbash=true mysql updateUser

## install a slave server:
* tclsh easy-installer.tcl --host=192.168.33.51 --profile=local-replica-profile.secret.yml --mocklist=mocklist-local.txt mysql installSlave
* tclsh easy-installer.tcl --host=192.168.33.51 --profile=local-replica-profile.secret.yml --notRunbash=true mysql startSlave

## create a dev mysql mirror
* ./easy-installer.tcl --host=xxx [--at=4:15] [--src=xxx] [disk-path=xxxxxx] mysql mirror

## debug
install mysql server.comment out socket.works.stop it.

## these file always exists.
/var/lib/mysql-files
/var/lib/mysql-keyring

必须先按照默认启动一次，然后再修my.cnf，再次重新启动即可。

mysql要更换目录的话，必须严格按照这样的程序：
1、默认安装，启动，执行mysql_secure_installation，停止
2、更改/etc/my.cnf，更改目录，重新启动，执行mysql_secure_installation.

if install failed, please follow these steps:
1. systemctl stop mysqld
2. rm -rvf /opt/mysql
3. rm -rvf /var/lib/mysql
4. rm -f /var/log/mysqld.log
5. yum remove -y mysql-community-server
