package provide ClusterMycnf 1.0

package require CommonUtil

package require confutil

namespace eval ::ClusterMycnf {
  if {[catch {open [file join $::baseDir mysql-cluster templates my.cnf]} fid o]} {
    puts stderr $fid
    exit 1
  } else {
    set lines [list]
    while {[gets $fid line] >= 0} {
      lappend lines $line
    }
    variable mycnfDic [::CommonUtil::splitSeg $lines {\[*]}]
    close $fid
  }
}

proc ::ClusterMycnf::writeToDisk {dest {needSubstitute 0}} {

  if {$needSubstitute} {
    substitute
  }
  set configDir [file dirname $dest]
  variable mycnfDic

  if {! [file exists $configDir]} {
    exec mkdir -p $configDir
  }

  if {[catch {open $dest w} fid o]} {
    puts stderr $fid
    exit 1
  } else {
    dict for {k v} $mycnfDic {
      foreach line $v {
          puts $fid $line
      }
    }
    close $fid
  }
}


# {[mysqld]} {[ndbd]} {[ndb_mgm]} {[ndb_mgmd]}
proc ::ClusterMycnf::substitute {} {
  variable mycnfDic

  set roles [::confutil::getMyRoles]

  set mgmHosts [join [::CommonUtil::getMgmHosts $::ymlDict] ,]
  dict for {k v} $mycnfDic {
    # this section in none sense. because we will run multiple instances in same machine.
    switch $k {
      {[mysqld]} {
        set nodeYml [::confutil::getNodeYml {MYSQLD}]
        if {[string length $nodeYml] > 0} {
          set nodeid [dict get $nodeYml NodeId]
          set DataDir [dict get $nodeYml DataDir]
          if {[string length $nodeid] > 0} {
            catch {exec mkdir -p $DataDir} msg o
            catch {exec chown -R mysql:mysql $DataDir}
            set kvDict [dict create {ndb-connectstring}  "nodeid=$nodeid,$mgmHosts" datadir $DataDir]
            variable mycnfDic [::CommonUtil::replaceItem $mycnfDic $k $kvDict]
          }
        }
      }
      {[ndbd]} {
        set nodeid [::confutil::getNodeId {NDBD}]
        if {[string length $nodeid] > 0} {
          set kvDict [dict create {connect-string}  "nodeid=$nodeid,$mgmHosts"]
          variable mycnfDic [::CommonUtil::replaceItem $mycnfDic $k $kvDict]
        }
      }
      {[ndb_mgm]} {
        set nodeid [::confutil::getNodeId {NDB_MGMD}]
        if {[string length $nodeid] > 0} {
          set kvDict [dict create {connect-string}  "nodeid=$nodeid,$mgmHosts"]
          variable mycnfDic [::CommonUtil::replaceItem $mycnfDic $k $kvDict]
        }
      }
      {[ndb_mgmd]} {
          set kvDict [dict get $::ymlDict NDB_MGMD_DEFAULT]
          puts $kvDict
          variable mycnfDic [::CommonUtil::replaceItem $mycnfDic $k $kvDict]
      }
    }
  }
}
