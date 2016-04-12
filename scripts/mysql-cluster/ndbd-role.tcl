package provide NdbdRole 1.0

package require confutil
package require AppDetecter

namespace eval ::NdbdRole {
  set role NDBD
}


proc ::NdbdRole::run {} {

  variable role

  set nodeYmls [::confutil::getNodeYmls $role]

  foreach nodeYml $nodeYmls {
    switch [dict get $::rawParamDict action] {
      ndbdstart {
        if {! [::AppDetecter::isRunning ndbd]} {
          exec ndbd
        } else {
          puts stdout "dnbd alreay running."
        }
      }
    }
  }
}
