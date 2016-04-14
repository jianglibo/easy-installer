package require AppDetecter
package require CommonUtil

package require MysqlInstaller
package require MysqlInit
package require SecureMe

if {! [::AppDetecter::isInstalled expect]} {
  puts stdout "expect not installed, start to install...."
  catch {exec yum install -y expect} msg o
}


set action [dict get $::rawParamDict action]

switch $action {
	install {
		::MysqlInstaller::install [dict get $::ymlDict IsMaster] $::ymlDict
	}
  secureInstallation {
    ::SecureMe::doSecure $::ymlDict
  }
  init {
    ::MysqlInit::init $::ymlDict
  }
	setupRepl {
		if {! [lindex $boxConfig 0]} {
			puts stdout "this is not master server, skiping........."
		}
	}
}
