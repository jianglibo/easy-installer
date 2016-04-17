package provide MysqlInstaller 1.0

package require AppDetecter
package require CommonUtil

namespace eval ::MysqlInstaller {
	variable tmpDir /opt/install-tmp
	if {[catch {
		exec mkdir -p $tmpDir
		} msg o]} {
		puts $msg
		exit 1
	}
}

proc ::MysqlInstaller::install {nodeYml rawParamDict} {
	if {[::AppDetecter::isInstalled {mysqld}]} {
		puts stdout "mysql already isInstalled, skip install."
		::CommonUtil::endEasyInstall
	}

	variable tmpDir
	set mysqlLog [dict get $nodeYml  log-error]
	set DownFrom [dict get $::ymlDict DownFrom]
	set rs [lindex [split $DownFrom /] end]

	cd $tmpDir
	puts stdout "start download from $DownFrom"
	::CommonUtil::spawnCommand curl -OL $DownFrom

	::AppDetecter::killByName yum

	exec yum localinstall -y $rs

	::CommonUtil::spawnCommand yum install -y mysql-community-server
}
