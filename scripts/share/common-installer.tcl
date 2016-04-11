package provide CommonInstaller 1.0

package require AppDetecter

namespace eval ::CommonInstaller {

}

proc ::CommonInstaller::installGcc {} {
  if {! [::AppDetecter::isInstalled cc]} {
    exec yum install -y gcc
  }

  if {! [::AppDetecter::isInstalled cc]} {
    puts stderr "install gcc failed, please try again."
  }
}
