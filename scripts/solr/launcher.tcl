package require CommonUtil
package require SolrInstaller

if {[catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::SolrInstaller::install $::ymlDict $::rawParamDict
  	}
    create {
  		::SolrInstaller::create $::ymlDict $::rawParamDict
    }
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o]} {
  puts $msg
  ::CommonUtil::endEasyInstall
}
