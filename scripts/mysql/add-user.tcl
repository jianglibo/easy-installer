package provide AddUser 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require Mycnf
package require SqlRunner

namespace eval ::AddUser {
}

proc ::AddUser::queryPassword {mpt} {
	set timeout 1000
	send_user "$mpt"
	expect_user -re "(.*)\n"
	return $expect_out(1,string)
}

proc ::AddUser::add {paramsDict rpass} {
	if {[catch {
		set UserName [dict get $paramsDict UserName]
		set FromHost [dict get $paramsDict FromHost]
		set DbName [dict get $paramsDict DbName]
		} msg o]} {
			puts "parameter 'ip, name, dbName' are mandatory."
			::CommonUtil::endEasyInstall
	}

	dict set paramsDict Password [queryPassword "please enter password for '$UserName'@'$FromHost' _enter_password:"]

	set sqls [list]
	lappend sqls [string map $paramsDict "create database DbName charset utf8;\r"]
	lappend sqls [string map $paramsDict "grant all privileges on DbName.* to 'UserName'@'FromHost' identified by 'Password';\r"]
	lappend sqls "flush privileges;\r"
	::SqlRunner::run $sqls $rpass
}

proc ::AddUser::addReplica {paramsDict rpass} {
	if {[catch {
		set UserName [dict get $paramsDict UserName]
		set FromHost [dict get $paramsDict FromHost]
		} msg o]} {
			puts "parameter 'ip, name, dbName' are mandatory."
			::CommonUtil::endEasyInstall
	}

	dict set paramsDict Password [queryPassword "please enter password for '$UserName'@'$FromHost' _enter_password:"]

	set sqls [list]
	lappend sqls [string map $paramsDict "CREATE USER 'UserName'@'FromHost' IDENTIFIED BY 'Password';\r"]
	lappend sqls [string map $paramsDict "GRANT REPLICATION SLAVE ON *.* TO 'UserName'@'FromHost';\r"]
	lappend sqls "flush privileges;\r"
	::SqlRunner::run $sqls $rpass
}
