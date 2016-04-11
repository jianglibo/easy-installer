package provide LauncherArgParser 1.0
package require cmdline

namespace eval ::LauncherArgParser {
  variable options {
      {runFolder.arg "" "the folder name in which script to run."}
      {action.arg "install" "which action to take."}
  }

  variable usage ":launcher.tcl \[options] filename ...\noptions:"
}


proc ::LauncherArgParser::parse {argv} {
  upvar $argv argvl
  variable options
  variable usage

  if {[catch {array set params [cmdline::getoptions argvl $options $usage]} msg o]} {
     if {"CMDLINE USAGE" eq [dict get $o -errorcode]} {
       puts $msg
     } else {
       puts $msg
     }
     exit 1
  } else {
    variable runFolder $params(runFolder)
    variable action $params(action)
  }
}

proc ::LauncherArgParser::getAction {} {
  variable action
  return $action
}

proc ::LauncherArgParser::getRunFolder {} {
  variable runFolder
  return $runFolder
}
