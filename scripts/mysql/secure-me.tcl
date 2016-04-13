package provide SecureMe 1.0
package require CommonUtil
package require Expect

namespace eval ::SecureMe {
}

proc ::SecureMe::doSecure {ymlDict} {
	set timeout 30
	set c 0
	set retryCount 0
	while {1} {
		if {$retryCount > 3} {
			::CommonUtil::endEasyInstall
		}
		if {$c} {
			send_user "new_password_again:\n"
			expect_user -re "(.*)\n"
			if {[string equal $password $expect_out(1,string)]} {
				break;
			} else {
				send_user "password not match!\n"
				incr retryCount
				set c 0
			}
		} else {
			send_user "please_enter_new_password:\n"
			expect_user -re "(.*)\n"
			set password $expect_out(1,string)
			set c 1
		}
	}

	set mysqlLog [dict get $ymlDict  log-error]
	set tpl [file join $::baseDir [dict get $ymlDict MyCnfTpl]]
	# mysql not initialized
	if {(! [file exists $mysqlLog]) || ([file size $mysqlLog] < 10)} {
		::Mycnf::substituteAndWrite $tpl $ymlDict /etc/my.cnf
		set dd [dict get $ymlDict datadir]
		if {! [file exists $dd]} {
			exec mkdir -p $dd
			exec chown -R mysql:mysql $dd
		}
		exec systemctl start mysqld
	}

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

	#if you successly run this code, password should not match.So it is harmless.
	puts stdout "temporary password is $tmppsd"


	#set password [dict get $::rawParamDict password]

	spawn -noecho mysql_secure_installation

	expect {
		"Enter password for user root:" {
			 exp_send "$tmppsd\r"
			 exp_continue
		 }
		"*Access denied for user*" {
			puts stdout "\nmysql already be initialized. skipped."
			::CommonUtil::endEasyInstall
		}
		"*Change the password for*" {
			puts stdout "\nmysql already be initialized. skipped."
			::CommonUtil::endEasyInstall
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
}
