#!/usr/bin/expect

set pass "password"
spawn $argv 1
expect "Password:";
send "$pass\n"
interact

