#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

if {[catch {open config.ini} fid o]} {
  puts stderr $fid
  exit 1
} else {
  set FirstReach 0
  set seq [list]
  set dic [dict create]
  set prevSeqName {}

  while {[gets $fid line] >= 0} {
    if {[string match \\\[*\] $line]} {
      set FirstReach 1
      if {[llength $seq] > 0} {
        dict set dic $lastSeqName $seq
        set seq [list]
      }
      set lastSeqName $line
      puts $line
    } else {
      if {$FirstReach} {
        lappend seq $line
      }
    }
  }
  close $fid
  dict set dic $lastSeqName $seq
  puts $dic
}

#NDB_MGMD DEFAULT
#NDB_MGMD
#NDBD DEFAULT
#NDBD
#MYSQLD DEFAULT
#MYSQLD
#API
