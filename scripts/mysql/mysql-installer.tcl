package provide MysqlInstaller 1.0

package require AppDetecter
package require CommonUtil

namespace eval ::MysqlInstaller {
	variable tmpDir /opt/install-tmp
	variable mysqlLog /var/log/mysqld.log
	variable rs mysql57-community-release-el7-7.noarch.rpm
	if {[catch {
		exec mkdir -p $tmpDir
		} msg o]} {
		puts $msg
		exit 1
	}
}

proc ::MysqlInstaller::install {} {
	if {[::AppDetecter::isInstalled {mysqld}]} {
		puts stdout "mysql already isInstalled, skip install."
		exit 0
	}
	variable tmpDir
	variable mysqlLog
	variable rs

	cd $tmpDir
	puts stdout "start download $rs"
	if {[catch {
			exec curl -OL http://dev.mysql.com/get/$rs >& /dev/null
		} msg o]} {
		puts $msg
		exit 1
	} else {
		puts stdout "download done."
	}

	::AppDetecter::killByName yum

	exec yum localinstall -y $rs

	catch {exec yum install -y mysql-community-server} msg o
	puts stdout $msg

	exec systemctl start mysqld
}
