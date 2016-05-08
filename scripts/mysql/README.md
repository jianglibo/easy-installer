## install a master server:
* tclsh easy-installer.tcl --host=192.168.33.50 --profile=local-profile.secret.yml --mocklist=mocklist-local.txt mysql install
* ./easy-installer.tcl --host=xxx mysql secureInstallation
* ***Do Something you don't want to be replica here***
* ./easy-installer.tcl --host=xxx server-id=1 mysql startMaster
* ./easy-installer.tcl --host=xxx UserName=xxx --FromHost=xxx --DbName=xxx mysql createUser
* ./easy-installer.tcl --host=xxx --UserName=xxx --FromHost=xxx mysql createReplicaUser

## install a slave server:
* ./easy-installer.tcl --host=xxx mysql install
* ./easy-installer.tcl --host=xxx mysql secureInstallation
* ./easy-installer.tcl --host=xxx server-id=2 mysql startSlave

## create a dev mysql mirror
* ./easy-installer.tcl --host=xxx [--at=4:15] [--src=xxx] [disk-path=xxxxxx] mysql mirror


## debug
install mysql server.comment out socket.works.stop it.

## these file always exists.
/var/lib/mysql-files
/var/lib/mysql-keyring

必须先按照默认启动一次，然后再修my.cnf，再次重新启动即可。
