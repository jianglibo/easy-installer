package provide SecureUtil 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require Mycnf
package require SqlRunner

namespace eval ::SecureUtil {
	variable TMP_PASSWORD Ake8023i^*asd
}

proc ::SecureUtil::doSecure {curPass newPass} {
  set timeout 10000
	spawn -noecho mysql_secure_installation
	set expired 0
	expect {
		"Enter password for user root: $" {
			 exp_send "$curPass\r"
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
#				send_user "_enter_password:"
#				expect_user -re "(.*)\n"
#  			exp_send "$expect_out(1,string)\r"
        exp_send "$newPass\r"
				exp_continue
			}
		"Re-enter new password: $" {
#			send_user "_enter_password:"
#			expect_user -re "(.*)\n"
#			exp_send "$expect_out(1,string)\r"
      exp_send "$newPass\r"
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
