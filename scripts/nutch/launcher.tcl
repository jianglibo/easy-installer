package require CommonUtil
package require HbaseInstaller

if {[catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::HbaseInstaller::install $::ymlDict $::rawParamDict
  	}
    start {
      ::HbaseInstaller::startStop $::ymlDict $::rawParamDict start
    }
    stop {
      ::HbaseInstaller::startStop $::ymlDict $::rawParamDict stop
    }
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
