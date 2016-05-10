package provide MysqlInstaller 1.0

package require AppDetecter
package require CommonUtil
package require PropertyUtil
package require SecureUtil

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
	#must comment out.
	::PropertyUtil::commentLines /etc/my.cnf [list socket]


		# if first start has server-id, it will has server-id. or else none.
	::CommonUtil::spawnCommand systemctl start mysqld

	after 1500 set state timeout
	vwait state

	set props [::PropertyUtil::properties2dict /etc/my.cnf]
	if {[dict exists $props log-error]} {
		set logFile [dict get $props log-error]
	} else {
		set logFile [dict get $props log_error]
	}
	if {[catch {open $logFile} fid o]} {
		puts stdout $fid
		::CommonUtil::endEasyInstall
	} else {
		while {[gets $fid line] >= 0} {
			if {[regexp {.*temporary password.*?:\s*(.*)} $line mh tmppsd]} {
				puts "found one $tmppsd"
			}
		}
		close $fid
	}

	::SecureUtil::securInstallation $tmppsd $::SecureUtil::TMP_PASSWORD

	after 2000 set state timeout
	vwait state

	::CommonUtil::spawnCommand systemctl stop mysqld
	::CommonUtil::spawnCommand systemctl stop mysqld
	::CommonUtil::spawnCommand systemctl stop mysqld

	after 2000 set state timeout
	vwait state
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
