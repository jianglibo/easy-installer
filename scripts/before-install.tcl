#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

# not used yet.
set ::baseDir [file dirname [info script]]

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  } else {
    lappend ::nameAction $a
  }
}

# modify hosts file.
if {! [file exists /etc/hosts.origin]} {
  exec cp /etc/hosts /etc/hosts.origin
} else {
  exec cp /etc/hosts.origin /etc/hosts
}


set mocklist [dict get $::rawParamDict mocklist]

set mockItems [dict create]

if {[catch {open [file join $::baseDir $mocklist]} fid o]} {
  puts $fid
  exit 1
} else {
  while {[gets $fid line] >= 0} {
    if {[string length [string trim $line]] == 0} {
      continue
    }
    if {[string first # $line] == -1} {
      set pair [split [string trim $line] =]
      dict set mockItems [lindex $pair 0] [lindex $pair 1]
    }
  }
}

dict for {k v} $mockItems {
  puts "$k=$v"
}

if {[catch {open /etc/hosts} fid o]} {
  puts $fid
  exit 1
} else {
  set lines [list]
  while {[gets $fid line] >= 0} {
    if {[string length [string trim $line]] == 0} {
      continue
    }
    set found 0
    dict for {host ip} $mockItems {
      if {[string match *${host}* $line]} {
        set found 1
        break
      }
    }
    if {! $found} {
      lappend lines $line
    }
  }

  dict for {host ip} $mockItems {
    lappend lines "$ip $host"
  }
  close $fid
  puts $lines
  if {[catch {open /etc/hosts w} fid o]} {
    puts $fid
    exit 1
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
}

# resotore hosts file.
