## install a master server:
* ./easy-installer.tcl --host=xxx server-id=1 mysql install
* ./easy-installer.tcl --host=xxx server-id=1 mysql secureInstallation
* ./easy-installer.tcl --host=xxx mysql dump
* ./easy-installer.tcl --host=xxx --UserName=xxx --FromHost=xxx --DbName=xxx mysql createUser
* ./easy-installer.tcl --host=xxx --UserName=xxx --FromHost=xxx mysql createReplicaUser

## install a slave server:
* ./easy-installer.tcl --host=xxx server-id=2 mysql install
* ./easy-installer.tcl --host=xxx server-id=2 mysql secureInstallation
* ./easy-installer.tcl --host=xxx --MasterHost=xxxx mysql firstStartSlave

## create a dev mysql mirror
* ./easy-installer.tcl --host=xxx --at=8:15 mysql mirror
