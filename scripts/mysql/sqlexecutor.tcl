#!/usr/bin/expect
set username [lindex $argv 0]
set password [lindex $argv 1]
set sql [lindex $argv 2]
set timeout 20
spawn -noecho mysql "-u$username" -p
set c 0
log_user 0
expect {
    -re {password:\s+$} {
        send "$password\r";
        exp_continue
    }
    -re {>\s+$} {
        if {$c == 0} {
          incr c
          send "$sql\n"
          exp_continue
        } else {
           puts $expect_out(buffer)
           send "exit\n"
        }
    }
}