#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

set ::baseDir [file dirname [info script]]

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  } else {
    lappend ::nameAction $a
  }
}

# resotore hosts file.
exec cp /etc/hosts.origin /etc/hosts

set epelRepo /etc/yum.repos.d/epel.repo
if {[file exists "${epelRepo}.origin"]} {
  exec cp "${epelRepo}.origin" $epelRepo
}

set scriptDir [file normalize [file join $::baseDir ..]]
puts "start cleanup $scriptDir ......"
exec rm -rvf $scriptDir
