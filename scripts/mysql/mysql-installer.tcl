package provide MysqlInstaller 1.0

package require AppDetecter
package require CommonUtil
package require PropertyUtil

namespace eval ::MysqlInstaller {
	variable tmpDir /opt/install-tmp
	if {[catch {
		exec mkdir -p $tmpDir
		} msg o]} {
		puts $msg
		::CommonUtil::endEasyInstall
	}
}

proc ::MysqlInstaller::yumInstall {ymlDict rawParamDict start} {
	variable tmpDir
#	set mysqlLog [dict get $ymlDict  log-error]
	set DownFrom [dict get $::ymlDict DownFrom]
	set rs [lindex [split $DownFrom /] end]

	cd $tmpDir
	puts stdout "start download from $DownFrom"
	::CommonUtil::spawnCommand curl -OL $DownFrom
	::AppDetecter::killByName yum
	::CommonUtil::spawnCommand yum localinstall -y $rs
	::CommonUtil::spawnCommand yum install -y mysql-community-server
	set serverId [dict get $ymlDict server-id]
	::PropertyUtil::changeOrAdd /etc/my.cnf [dict create server-id $serverId]

	if {$start} {
		# if first start has server-id, it will has server-id. or else none.
		::CommonUtil::spawnCommand systemctl start mysqld
		::CommonUtil::spawnCommand systemctl stop mysqld
	}
}

proc ::MysqlInstaller::install {ymlDict rawParamDict {start 1}} {
	if {[::AppDetecter::isInstalled {mysqld}]} {
		puts stdout "mysql already isInstalled, skip install."
		return 1
	}
	yumInstall $ymlDict $rawParamDict $start
}


# -------------unused code------------------------------
proc ::MysqlInstaller::bundleInstall {ymlDict rawParamDict} {
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
