#!/usr/bin/expect

set pass "admin"

spawn ssh board_iss_admin
expect "password:"
send "$pass\n"

expect "#";
# send "copy tftp://192.168.1.3/curr_image_iss image\n"
# 
# expect "Copied";
send "reload\n"

expect "You haven't saved your changes. Are you sure you want to continue?"
send "y"

expect "This command will reset the whole system and disconnect your current session. Do you want to continue?"
send "y"

interact

