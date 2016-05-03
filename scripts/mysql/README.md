## install a master server:
* ./easy-installer.tcl --host=xxx mysql install
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

 http://218.108.192.216:80/1Q2W3E4R5T6Y7U8I9O0P1Z2X3C4V5B/repo.mysql.com/yum/mysql-tools-community/el/7/x86_64/repodata/9f06a0cf97c4368f78e237811e6b9fb324362a64-primary.sqlite.bz2
