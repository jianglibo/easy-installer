package require CommonUtil
package require BootSetup

if {[catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::BootSetup::init $::ymlDict $::rawParamDict
  	}
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
