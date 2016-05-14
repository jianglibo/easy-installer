#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

set ::baseDir [file dirname [info script]]
lappend auto_path [file join $::baseDir share]

set ::rawParamDict [dict create]
foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  }
}

if {! [dict exists $::rawParamDict runFolder] } {
  puts stderr "paramter -runFolder does not exists!"
  puts stdout "\nend_of_easy_install\n"
  exit 0
}

lappend auto_path [file join $::baseDir [dict get $::rawParamDict runFolder]]

# now start
package require CommonUtil
package require YamlUtil
package require AppDetecter

if {! [dict exists $::rawParamDict action]} {
  dict set rawParamDict action install
}



if {[dict exists $::rawParamDict profile]} {
  set profile [dict get $::rawParamDict profile]
} else {
  set profile default.yml
}

set cfgFile [file join $::baseDir [dict get $::rawParamDict runFolder] profiles $profile]

if {! [string match *.yml $cfgFile]} {
  set cfgFile "$cfgFile.yml"
}

if {[file exists $cfgFile]} {
#  set ::ymlDict [::CommonUtil::mergeConfig $::rawParamDict [::CommonUtil::loadYaml $cfgFile]]
  set ::ymlDict [::YamlUtil::loadYaml $cfgFile]
} else {
  puts stdout "profile are mandatory. or replace a local-profile.yml in your app script folder!!!!"
  ::CommonUtil::endEasyInstall
}

source [file join $::baseDir [dict get $::rawParamDict runFolder] launcher.tcl]

package require CommonUtil
package require OsUtil

::OsUtil::doCommonTasks $::ymlDict $::rawParamDict

::CommonUtil::endEasyInstall
