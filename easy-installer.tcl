#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

# paramter format: --name=value
foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  }
}

if {! [dict exists $::rawParamDict appname]} {

}
# upload scripts
puts [exec ssh root@192.168.33.53 "ls -lh"]
