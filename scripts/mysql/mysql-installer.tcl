package provide MysqlInstaller 1.0

package require AppDetecter
package require CommonUtil

namespace eval ::MysqlInstaller {
	variable tmpDir /opt/install-tmp
	if {[catch {
		exec mkdir -p $tmpDir
		} msg o]} {
		puts $msg
		::CommonUtil::endEasyInstall
	}
}

proc ::MysqlInstaller::yumInstall {nodeYml rawParamDict} {
	variable tmpDir
	set mysqlLog [dict get $nodeYml  log-error]
	set DownFrom [dict get $::ymlDict DownFrom]
	set rs [lindex [split $DownFrom /] end]

	cd $tmpDir
	puts stdout "start download from $DownFrom"
	::CommonUtil::spawnCommand curl -OL $DownFrom

	::AppDetecter::killByName yum

	::CommonUtil::spawnCommand yum localinstall -y $rs

	::CommonUtil::spawnCommand yum install -y mysql-community-server
}

proc ::MysqlInstaller::bundleInstall {nodeYml rawParamDict} {
	set DownFrom [dict get $::ymlDict BundleDownFrom]
	set rs [lindex [split $DownFrom /] end]
	set d [file rootname $rs]

	if {! [file exists $d]} {
		exec mkdir $d
	}
	cd $d
	if {! [file exists $rs]} {
		::CommonUtil::spawnCommand curl -OL $DownFrom
	}
	::CommonUtil::spawnCommand tar -xf $rs
}

proc ::MysqlInstaller::install {nodeYml rawParamDict} {
	if {[::AppDetecter::isInstalled {mysqld}]} {
		puts stdout "mysql already isInstalled, skip install."
		::CommonUtil::endEasyInstall
	}
	yumInstall $nodeYml $rawParamDict
}
