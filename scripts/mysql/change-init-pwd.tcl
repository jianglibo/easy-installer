package provide ChangeInitPwd 1.0

package require Expect

namespace eval ::ChangeInitPwd {

}

proc ::ChangeInitPwd::doChange {oldPwd newPwd} {
  set pid [spawn mysql -uroot -p]

#id no duplicated match, use exp_continue
  expect {
    "Enter password: $" {
      exp_send "$oldPwd\r"
      exp_continue
   }
   "Welcome to" {exp_send "SHOW MASTER STATUS;\n" ; exp_continue}
   "1 row in set" {
      send_user "expected result is: $expect_out(buffer)"
      exp_send "select 1+1;\n"
    }
  }
}

# What's in $expect_out(buffer)? from previous match position(not include), to this match position(include).!!!!!!!!!!!!

expect {
  "Enter password: $" {
      exp_send newPass%123\n
      array set expect_out {buffer " "}
      exp_continue
   }
  "Welcome to" {exp_send "SHOW MASTER STATUS;\n" ; exp_continue}
  -re "(mysql-bin\.\\d*).*?(\\d+)" {
     send_user |-------------------aaaaaaaaaa\n\n
     send_user "$expect_out(1,string)\n"
     send_user "$expect_out(2,string)"
     exp_send "select 1+1;\n"
   }
  timeout {puts timeout}
}
