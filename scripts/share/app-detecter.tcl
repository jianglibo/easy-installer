package provide AppDetecter 1.0

namespace eval ::AppDetecter {

}

proc ::AppDetecter::isInstalled {execName} {
  catch {exec which $execName} msg o
  if {[dict get $o -code] == 0} {
    return 1
  }
  return 0
}

proc ::AppDetecter::mysqlInstalled {} {
  isInstalled ndb_mgmd
}

proc ::AppDetecter::getPsLines {an} {
  catch {exec ps -A | grep $an} pss o
  set tmp [list]
  if {[string length $pss] > 0} {
    set lines [split $pss \n]
    foreach line $lines {
      if {[lsearch -exact $line $an] != -1} {
        lappend tmp $line
      }
    }
  }
  return $tmp
}

proc ::AppDetecter::isRunning {an} {
  set lines [getPsLines $an]
  if {[llength $lines] > 0} {
    return 1
  } else {
    return 0
  }
}

proc ::AppDetecter::killByName {pname} {
  set lines [getPsLines $pname]

  foreach line $lines {
    set pid [string trim [lindex $line 0]]
    if {[string length $pid] > 0} {
      catch {exec kill -s 9 $pid} msg o
    }
  }
}
