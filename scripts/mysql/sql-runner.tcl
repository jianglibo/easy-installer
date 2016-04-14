package provide SqlRunner 1.0
package require Expect

namespace eval ::SqlRunner {
}

proc ::SqlRunner::run {sqls, password} {
  spawn -noecho mysql -uroot -p
	set sqls [list]

	foreach hu [dict get $::ymlDict ALLOWED_USERS] {
		lappend sqls [string map $hu "create database DbName charset utf8;\r"]
	 	lappend sqls [string map $hu "grant all privileges on DbName.* to 'UserName'@'HostName' identified by 'Password';\r"]
	}

	if {$isMaster} {
		foreach slv [dict get $::ymlDict SLAVES] {
			lappend sqls "CREATE USER '[dict get $::ymlDict SLAVE_USER]'@'[dict get $slv HostName]' IDENTIFIED BY '[dict get $::ymlDict SLAVE_PASSWORD]';"
			lappend sqls "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'[dict get $slv HostName]';"
		}
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
