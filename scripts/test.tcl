#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

set ::baseDir [file dirname [info script]]
lappend auto_path $::baseDir

set ::rawParamDict [dict create]

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  }
}

puts $::rawParamDict

set tmpl [list]

foreach v $::argv {
  if {[string first --f= $v] != 0} {
    lappend tmpl $v
  }
}

set ::argv $tmpl


if {[dict exists $::rawParamDict f] } {
  source [file join $::baseDir [dict get $::rawParamDict f]]
} else {
  puts stderr "paramter --f does not exists!"
  exit 1
}
