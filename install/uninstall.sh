#!/usr/bin/expect

set timeout 60
if {$argc != 1} {
    send_user "cont get the uninstall file path!"
    exit
}

set uninstall [lindex $argv 0]

spawn $uninstall
expect "CONTINUE:"
send "\n"
expect "options::"
send "1\n"
expect "CONTINUE:"
send "\n"
set timeout 600
expect "(Y/N):"
send "N\n"
expect eof