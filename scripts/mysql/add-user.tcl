package provide AddUser 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require Mycnf

namespace eval ::AddUser {
}

proc ::AddUser::add {paramsDict rpass} {
	if {[catch {
		set UserName [dict get $paramsDict UserName]
		set HostName [dict get $paramsDict HostName]
		set DbName [dict get $paramsDict DbName]
		} msg o]} {
			puts "parameter 'ip, name, dbName' are mandatory."
			::CommonUtil::endEasyInstall
	}
	set timeout 1000
	send_user "please enter password for '$UserName'@'$HostName' _enter_password:"
	expect_user -re "(.*)\n"
	set upass $expect_out(1,string)
	dict set paramsDict Password $upass

	set sqls [list]
	lappend sqls [string map $paramsDict "create database DbName charset utf8;\r"]
	lappend sqls [string map $paramsDict "grant all privileges on DbName.* to 'UserName'@'HostName' identified by 'Password';\r"]
	lappend sqls "flush privileges;\r"
	lappend sqls "exit\r"

  spawn -noecho mysql -uroot -p
	set count 0
	expect {
		"Enter password: $" {
			exp_send "$rpass\r"
			exp_continue
		}
		"mysql> $" {
			exp_send [lindex $sqls $count]
			incr count
			exp_continue
		}
		eof {}
		timeout {
			::CommonUtil::endEasyInstall
		}
	}
}
