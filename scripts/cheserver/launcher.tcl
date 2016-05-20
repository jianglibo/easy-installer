package require AppDetecter
package require CommonUtil
package require CheInstaller

if {[catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::CheInstaller::install $::ymlDict $::rawParamDict
  	}
    start {
      ::CheInstaller::startStop run
    }
    stop {
      ::CheInstaller::startStop stop
    }
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
