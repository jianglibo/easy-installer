package provide MysqlInit 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect

namespace eval ::MysqlInit {
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

proc ::MysqlInit::init {} {
	if {! [::AppDetecter::isInstalled {mysqld}]} {
		puts stdout "mysql has not been installed, start install..."
		::MysqlInstaller::install
	}

	variable tmpDir
	variable mysqlLog
	variable rs

	if {[catch {open $mysqlLog} fid o]} {
		puts stdout $fid
		exit 1
	} else {
		while {[gets $fid line] >= 0} {
			if {[string match "*temporary password*:*" $line]} {
				set tmppsd [string trim [lindex [split [string trim $line] :] end]]
				break
			}
		}
		close $fid
	}

	puts stdout "temporary password is $tmppsd"

	set password [dict get $::rawParamDict password]

	spawn -noecho mysql_secure_installation

	expect {
		"Enter password for user root:" {
			 exp_send "$tmppsd\r"
			 exp_continue
		 }
		"*Access denied for user*" {
			puts stdout "mysql already be initialized. skipped."
			exit 0
		}
		"*Change the password for*" {
			puts stdout "mysql already be initialized. skipped."
			exit 0
		}
		eof {}
		timeout {
			puts stdout "let timeout."
		}
	}
	expect {
		"The existing password for the user account root has expired*New password:" {
  			exp_send "$password\r"
				exp_continue
			}
			"Re-enter new password:" {
				exp_send "$password\r"
				exp_continue
			}
			"any other key for No)" {
				exp_send "n\r"
			}
			eof {}
			timeout {}
		}
	expect {
		"Remove anonymous users?*any other key for No)" {exp_send "y\r" ; exp_continue}
		"Disallow root login remotely?* any other key for No)" {exp_send "y\r" ; exp_continue}
		"Remove test database and access to it?* any other key for No)" {exp_send "y\r"; exp_continue}
		"Reload privilege tables now?* any other key for No)" {exp_send "y\r"; exp_continue}
		eof {}
		timeout {}
	}

	spawn -noecho mysql -uroot -p

	set sqls [list]

	foreach hu [dict get $::ymlDict ALLOWED_USERS] {
		lappend sqls [string map $hu "create database DbName charset utf8;\r"]
	 	lappend sqls [string map $hu "grant all privileges on DbName.* to 'UserName'@'HostName' identified by 'Password';\r"]
	}

	lappend sqls "flush privileges;\r"
	lappend sqls "exit\r"

	set num [llength $sqls]
  set count 0

	expect {
		"Enter password: $" {
			exp_send "$password\r"
			exp_continue
		}
		"mysql> $" {
			if {$count < $num} {
				exp_send [lindex $sqls $count]
				incr count
				exp_continue
			}
		}
		eof {}
		timeout {}
	}
}
