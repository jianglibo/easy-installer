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
