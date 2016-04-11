package provide MysqldRole 1.0

package require confutil
package require AppDetecter

namespace eval ::MysqldRole {
  set role MYSQLD
}


proc ::MysqldRole::run {} {

  variable role

  set nodeYmls [::confutil::getNodeYmls $role]

  foreach nodeYml $nodeYmls {
    #mysql_install_db --user=mysql --datadir=/opt
    #mysqld_safe --user=mysql --ndb-nodeid=nodeid --datadir=/opt/xxxx --port=3307 &
    switch [dict get $::rawParamDict action] {
      mysqldstart {
        set dd [dict get $nodeYml DataDir]
        if {! [file exists [file join $dd mysql]]} {
          if {! [::AppDetecter::isInstalled cpan]} {
            puts stdout "cpan not installed, start to install........"
            catch {exec yum install -y cpan} msg o
          }
          set mid "mysql_install_db --user=mysql --datadir=$dd"
          catch {[exec {*}$mid]} msg o
          puts stdout $msg
        }

        set execCmd "mysqld_safe --user=mysql --ndb-nodeid=[dict get $nodeYml NodeId] --datadir=$dd --port=[dict get $nodeYml Port] >/dev/null &"
        puts stdout "starting mysql: $execCmd"
        exec {*}$execCmd
      }
    }
  }
}
