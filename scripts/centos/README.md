tclsh easy-installer.tcl --host=10.74.111.62 centos disableIpv6

tclsh easy-installer.tcl --host=10.74.111.62 --runBash=true --disk=/dev/sdb centos addNewDisk

tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --nameserver=192.168.33.53 centos setupResolver

tclsh easy-installer.tcl --host=192.168.33.53 --nameserver=223.5.5.5 centos setupResolver

tclsh easy-installer.tcl --host=10.74.111.62 centos jps

#tclsh easy-installer.tcl --host=xxx --fixRepoTo=aliyun centos fixRepo
# use fastestmirror instead of change it.
