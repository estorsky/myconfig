#!/bin/sh

departments=$(curl -s http://eltex.loc/index.php | grep -Eo 'category&amp;catid=[0-9]{1,4}' | cut -d'=' -f2 | tr '\n' ' ')

total_cnt=0
for i in $departments
do
	echo "Checking department $i"
	people_in_dep=$(curl -s http://eltex.loc/index.php\?option\=com_qcontacts\&view\=category\&catid\=$i | grep -c "icon gym-icon")
	echo "Found $people_in_dep people"
	total_cnt=$(($total_cnt+$people_in_dep))
	# sleep 0.1
done
echo "Total people in gym: $total_cnt people"
