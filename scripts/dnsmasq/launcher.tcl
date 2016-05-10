package require CommonUtil
package require DnsmasqInstaller

if {[catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::DnsmasqInstaller::install $::ymlDict $::rawParamDict
  	}
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
