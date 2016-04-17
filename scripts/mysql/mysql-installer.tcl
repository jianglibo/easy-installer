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

#	if {! [dict exists $rawParamDict server-id]} {
#		puts stdout "\nparameter server-id is mandantory.\n"
#		::CommonUtil::endEasyInstall
#	}

	variable tmpDir
	set mysqlLog [dict get $nodeYml  log-error]
	set DownFrom [dict get $::ymlDict DownFrom]
	set rs [lindex [split $DownFrom /] end]

	cd $tmpDir
	puts stdout "start download from $DownFrom"
	set timeout 10000
	spawn curl -OL $DownFrom
	expect {
		eof {
			puts "done."
		}
		timeout {
			puts "timeout"
		}
	}
#	if {[catch {

#		} msg o]} {
#		puts $msg
#		::CommonUtil::endEasyInstall
#	} else {
#		puts stdout "download done."
#	}

	::AppDetecter::killByName yum

	exec yum localinstall -y $rs
	spawn yum install -y mysql-community-server
	expect {
		eof {
			puts "done."
		}
		timeout {
			puts "timeout"
		}
	}


#	exec systemctl start mysqld
}
