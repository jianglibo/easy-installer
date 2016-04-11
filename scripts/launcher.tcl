#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

set ::baseDir [file dirname [info script]]
lappend auto_path $::baseDir

set ::rawParamDict [dict create]

package require CommonUtil
package require AppDetecter

if {! [::AppDetecter::isInstalled expect]} {
  puts stdout "expect not installed, start to install...."
  catch {exec yum install -y expect} msg o
}

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  }
}

if {! [dict exists $::rawParamDict action]} {
  dict set rawParamDict action install
}

if {[dict exists $::rawParamDict runFolder] } {
  source [file join $::baseDir [dict get $::rawParamDict runFolder] launcher.tcl]
} else {
  puts stderr "paramter -runFolder does not exists!"
  exit 1
}

set profile local-profile.yml

if {[dict exists $::rawParamDict profile]} {
  set profile [dict get $::rawParamDict profile]
}

set cfgFile [file join $::baseDir [dict get $::rawParamDict runFolder] $profile]

if {! [string match *.yml $cfgFile]} {
  set cfgFile "$cfgFile.yml"
}

if {[file exists $cfgFile]} {
  set ::ymlDict [::CommonUtil::loadYaml $cfgFile]  
}
