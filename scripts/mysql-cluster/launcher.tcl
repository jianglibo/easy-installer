package require yaml

package require MysqlClusterInstaller
package require CommonUtil

if {! [dict exists $::rawParamDict profile]} {
  puts stderr "parameter --profile doesn't exists!"
  exit 1
}

set cfgFile [file join $::baseDir mysql-cluster [dict get $::rawParamDict profile]]

if {! [string match *.yml $cfgFile]} {
  set cfgFile "$cfgFile.yml"
}

set ::ymlDict [::CommonUtil::loadNormalizedYmlDic $cfgFile]
package require confutil
package require ClusterMycnf
package require confini
package require ManageRole
package require MysqldRole
package require NdbdRole

set myroles [::confutil::getMyRoles]

if {! [llength $myroles]} {
  puts stderr "host ip not exists in [dict get $::rawParamDict profile]"
  exit 1
}

dict for {k v} $::ymlDict {
  set hasRole [expr [lsearch $myroles $k] != -1]
  if {$hasRole && [dict exists $v DataDir]} {
    catch {exec mkdir -p [dict get $v DataDir]} msg o
  }
}

switch [dict get $::rawParamDict action] {
  install {
    ::MysqlClusterInstaller::install /opt/install-tmp
  }
  config {
    # write my.cnf file. always need.
    ::ClusterMycnf::writeToDisk /etc/my.cnf 1
    set cf [dict get $::ymlDict NDB_MGMD_DEFAULT config-file]
    ::confini::writeToDisk $cf 1
  }
  mgmstart {
    if {[lsearch -exact $myroles NDB_MGMD] != -1} {
      ::ManageRole::run
    } else {
      puts stdout "not a NDB_MGMD node, skipping"
    }
  }
  mysqldstart {
    if {[lsearch -exact $myroles MYSQLD] != -1} {
      ::MysqldRole::run
    } else {
      puts stdout "not a MYSQLD node, skipping"
    }
  }
  ndbdstart {
    if {[lsearch -exact $myroles NDBD] != -1} {
      ::NdbdRole::run
    } else {
      puts stdout "not a NDBD node, skipping"
    }
  }
  default {

  }
}
