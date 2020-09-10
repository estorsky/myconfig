#!/usr/bin/expect 

set pass "password"
spawn firmware_install.sh
expect "Password:";
send "$pass\n"
interact

