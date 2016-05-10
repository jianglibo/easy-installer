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

# only change two properties. server-id, and datadir
proc ::MysqlInstaller::modifyMyCnf {propertiesDict} {
	::PropertyUtil::changeOrAdd /etc/my.cnf [dict create server-id [dict get $propertiesDict server-id]]
	::PropertyUtil::changeOrAdd /etc/my.cnf [dict create datadir [dict get $propertiesDict datadir]]
	::PropertyUtil::commentLines /etc/my.cnf [list socket]
}

proc ::MysqlInstaller::getPropertiesDict {ymlDict rawParamDict} {
	set mycnf [file join $::baseDir [dict get $rawParamDict {runFolder}] [dict get $ymlDict {mycnf}]]
	set propertiesDict [::PropertyUtil::properties2dict $mycnf]
	# fix server-id
	dict set propertiesDict server-id [dict get $ymlDict server-id]
	# add mycnf key for later access.
	dict set propertiesDict mycnfFile $mycnf
	return $propertiesDict
}

proc ::MysqlInstaller::extractTmpPwd {propertiesDict} {
	set logFile [dict get $propertiesDict log-error]
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
	return $tmppsd
}

proc ::MysqlInstaller::yumInstall {ymlDict rawParamDict start} {
	variable tmpDir
#	set mysqlLog [dict get $ymlDict  log-error]
	set DownFrom [dict get $ymlDict DownFrom]
	set rs [lindex [split $DownFrom /] end]

	cd $tmpDir
	puts stdout "start download from $DownFrom"
	::CommonUtil::spawnCommand curl -OL $DownFrom
	::AppDetecter::killByName yum
	::CommonUtil::spawnCommand yum localinstall -y $rs
	::CommonUtil::spawnCommand yum install -y mysql-community-server
	exec cp /etc/my.cnf /etc/my.cnf.origin

	set propertiesDict [getPropertiesDict $ymlDict $rawParamDict]

	modifyMyCnf $propertiesDict
	# log-bin not enabled.
	::CommonUtil::spawnCommand systemctl start mysqld
	set rpass [dict get $ymlDict RootPassword]
	::SecureUtil::securInstallation [extractTmpPwd $propertiesDict] $rpass

	::CommonUtil::spawnCommand systemctl stop mysqld

	# change my.cnf again. this time enable log-bin
	exec cp [dict get $propertiesDict mycnfFile] /etc/my.cnf
	modifyMyCnf $propertiesDict

	::CommonUtil::spawnCommand systemctl start mysqld
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
