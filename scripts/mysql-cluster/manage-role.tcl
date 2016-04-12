package provide ManageRole 1.0

package require confutil
package require AppDetecter

namespace eval ::ManageRole {
  set role NDB_MGMD
}

proc ::ManageRole::run {} {

  variable role

  set thisNodeId [::confutil::getNodeId $role]

  set DataDir [dict get $::ymlDict $role DataDir]

  if {! [file exist [file join $DataDir $thisNodeId]]} {
    exec mkdir -p [file join $DataDir $thisNodeId]
  }

  switch [dict get $::rawParamDict action] {
    mgmstart {
      if {! [::AppDetecter::isRunning ndb_mgmd]} {
        exec ndb_mgmd
      } else {
        puts stdout "ndb_mgmd already running."
      }
    }
  }
}
