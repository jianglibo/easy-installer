package provide SecureMe 1.0
package require CommonUtil
package require Expect

namespace eval ::SecureMe {
}

# when first start, bin-log not enabled.

proc ::SecureMe::enableBinLog {} {
  if {! [dict exists $::rawParamDict server-id]} {
    puts "\nserver-id is mandatory.\n"
    ::CommonUtil::endEasyInstall
  }
  set scripts {
    if {[string first #log-bin= $line] == 0} {
      lappend lines "log-bin=mysql-bin"
    } elseif {[string first #server-id= $line] == 0} {
      lappend lines "server-id=[dict get $::rawParamDict server-id]"
    } elseif {[string first #innodb_flush_log_at_trx_commit= $line] == 0} {
      lappend lines "innodb_flush_log_at_trx_commit=1"
    } elseif {[string first #sync_binlog= $line] == 0} {
      lappend lines "sync_binlog=1"
    } else {
      lappend lines $line
    }
	}
  ::CommonUtil::substFileLineByLine /etc/my.cnf $scripts
  ::CommonUtil::spawnCommand systemctl restart mysqld
}

proc ::SecureMe::doSecure {ymlDict} {

	set mysqlLog [dict get $ymlDict  log-error]
	set tpl [file join $::baseDir [dict get $ymlDict MyCnfTpl]]
	# mysql not initialized
	if {(! [file exists $mysqlLog]) || ([file size $mysqlLog] < 10)} {
		::Mycnf::substituteAndWrite $tpl $ymlDict /etc/my.cnf
		set dd [dict get $ymlDict datadir]
    if {[catch {exec grep -Ei "^mysql:" /etc/passwd} msg o]}
			exec groupadd mysql
			exec useradd -r -g mysql -s /bin/false mysql
		}
		if {! [file exists $dd]} {
			exec mkdir -p $dd
			exec chown -R mysql:mysql $dd
		}
		::CommonUtil::spawnCommand systemctl start mysqld
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
  set timeout 10000
	spawn -noecho mysql_secure_installation

	set expired 0

	expect {
		"Enter password for user root: $" {
			 exp_send "$tmppsd\r"
			 exp_continue
		 }
		"*Access denied for user*" {
			puts stdout "\nmysql already be initialized. skipped."
			::CommonUtil::endEasyInstall
		}
		"Change the password for root ? ((Press y|Y for Yes, any other key for No) : $" {
			if {$expired} {
				exp_send "n\r"
				exp_continue
			} else {
				puts stdout "\nmysql already be initialized. skipped."
				::CommonUtil::endEasyInstall
			}
		}
		"The existing password for the user account root has expired*New password: $" {
				set expired 1
				send_user "_enter_password:"
				expect_user -re "(.*)\n"
  			exp_send "$expect_out(1,string)\r"
				exp_continue
			}
		"Re-enter new password: $" {
			send_user "_enter_password:"
			expect_user -re "(.*)\n"
			exp_send "$expect_out(1,string)\r"
			exp_continue
		}
		"Sorry, passwords do not match.*New password: $" {
			exp_continue
		}
		"satisfy the current policy requirements*New password: $" {
			::CommonUtil::endEasyInstall
		}
		"Remove anonymous users?*any other key for No) : $" {exp_send "y\r" ; exp_continue}
		"Disallow root login remotely?* any other key for No) : $" {exp_send "y\r" ; exp_continue}
		"Remove test database and access to it?* any other key for No) : $" {exp_send "y\r"; exp_continue}
		"Reload privilege tables now?* any other key for No) : $" {exp_send "y\r"}
		eof {}
		timeout
	}
}
