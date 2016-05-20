package require CommonUtil
package require HadoopInstaller

if {[catch {
  set action [dict get $::rawParamDict action]
  switch $action {
  	install {
  		::HadoopInstaller::install $::ymlDict $::rawParamDict
  	}
    formatCluster {
      ::HadoopInstaller::formatCluster $::ymlDict $::rawParamDict
    }
    start {
      ::HadoopInstaller::startStop $::ymlDict $::rawParamDict start
    }
    stop {
      ::HadoopInstaller::startStop $::ymlDict $::rawParamDict stop
    }
    report {
      ::HadoopInstaller::report $::ymlDict $::rawParamDict
    }
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
