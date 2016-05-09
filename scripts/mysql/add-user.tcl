package provide AddUser 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require Mycnf
package require SqlRunner

namespace eval ::AddUser {
}

proc ::AddUser::add {paramsDict ymlDict} {
	set sqls [list]
	set dbUsers [dict get $ymlDict dbUsers]
	foreach u $dbUsers {
		lappend sqls [string map $u "create database DbName charset utf8;\r"]
		lappend sqls [string map $u "grant all privileges on DbName.* to 'UserName'@'FromHost' identified by 'Password';\r"]
	}
	lappend sqls "flush privileges;\r"
	::SqlRunner::run $sqls [dict get $ymlDict RootPassword]
}

proc ::AddUser::addReplica {paramsDict ymlDict} {
	set sqls [list]
	set replicaUsers [dict get $ymlDict replicaUsers]
	foreach u $replicaUsers {
		lappend sqls [string map $u "CREATE USER 'UserName'@'FromHost' IDENTIFIED BY 'Password';\r"]
		lappend sqls [string map $u "GRANT REPLICATION SLAVE ON *.* TO 'UserName'@'FromHost';\r"]
	}
	lappend sqls "flush privileges;\r"
	::SqlRunner::run $sqls [dict get $ymlDict RootPassword]
}


proc ::AddUser::queryPassword {mpt} {
	set timeout 1000
	send_user "$mpt"
	expect_user -re "(.*)\n"
	return $expect_out(1,string)
}
