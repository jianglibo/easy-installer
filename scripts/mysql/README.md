## install a master server:
* ./easy-installer.tcl --host=xxx mysql install
* ./easy-installer.tcl --host=xxx mysql secureInstallation
* ***Do Something you don't want to be replica here***
* ./easy-installer.tcl --host=xxx server-id=1 mysql enableBinLog
* ./easy-installer.tcl --host=xxx --UserName=xxx --FromHost=xxx --DbName=xxx mysql createUser
* ./easy-installer.tcl --host=xxx --UserName=xxx --FromHost=xxx mysql createReplicaUser

## install a slave server:
* ./easy-installer.tcl --host=xxx mysql install
* ./easy-installer.tcl --host=xxx mysql secureInstallation
* ./easy-installer.tcl --host=xxx server-id=2 mysql enableBinLog
* ./easy-installer.tcl --host=xxx mysql startSlave

## create a dev mysql mirror
* ./easy-installer.tcl --host=xxx --at=8:15 mysql mirror
