package provide ManageRole 1.0

package require confutil

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
      exec ndb_mgmd
    }
  }
}
