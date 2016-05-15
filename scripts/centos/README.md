tclsh easy-installer.tcl --host=xxx centos disableIpv6


tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --nameserver=192.168.33.53 --notRunBash=true centos setupResolver

tclsh easy-installer.tcl --host=192.168.33.53 --nameserver=223.5.5.5 --notRunBash=true centos setupResolver

#tclsh easy-installer.tcl --host=xxx --fixRepoTo=aliyun centos fixRepo
# use fastestmirror instead of change it.
