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
