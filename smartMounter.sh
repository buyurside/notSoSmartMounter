#!/bin/bash


path2logs="/var/log/smartmounter"
path2collect="/dev/disk/by-uuid/"
#path2rules=""			# coming soon
#path2mount_default="/mnt/"	# coming soon

declare -a uuids mounteds blacklisteds #, rules


if [ ! -d $path2logs ]; then
	mkdir $path2logs
else
	if [ -s $path2logs/mounteds ]; then
		echo "" > $path2logs/mounteds
	elif [ -s $path2logs/blacklisteds ]; then
		echo "" > $path2logs/blacklisteds
	fi
fi

#function fMounter() {
#
## 1 - ${uuids[$i]}
#	if [ ! -d /mnt/$1 ]; then
#		mkdir /mnt/$1
#
#		if [ $? -ne 0 ]; then
#			blacklisteds+=( $1 )
#			continue
#		fi
#	fi
#
#	mount /mnt/$1 $path2collect$1 
#	if [ -z $? ]; then
#		mounteds+=( $1 )
#	else
#		blacklisteds+=( $1 )
#	fi
#}

function FLoger() {
	echo "" > $path2logs/mounteds
	echo "" > $path2logs/blacklisteds

	for (( i = 0; i < ${#mounteds[@]}; i++ ));
	do
		echo "${mounteds[$i]}" >> $path2logs/mounteds
	done
	for (( i = 0; i < ${#blacklisteds[@]}; i++ ));
	do
		echo "${blacklisteds[$i]}" >> $path2logs/blacklisteds
	done
}

function FMntCleaner() {
	maDirs=( $(ls /mnt) )

	if [ ${#maDirs[@]} -gt 0 ]; then
		for (( i = 0; i < ${#maDirs[@]}; i++ ));
		do
			if [ -z $( echo "$( /sbin/blkid -o export )" | grep "${maDirs[$i]}" ) ];
			then
				rm -R "/mnt/${maDirs[$i]}"
			fi
		done
	fi
}

while [ true ];
do
	uuids=( $(ls $path2collect) )
	#while FSO= read -r line;
	#do
	#	$line=$( cut -d'#' -f1 <<< $line )
	#	if [ -n $line ]; then
	#		rules+=( $line )
	#	fi
	#done <<< $path2rules


	for (( i = 0; i < ${#uuids[@]}; i++ ));
	do
		if [ -e $path2logs/blacklisteds ]; then
			isBlacklisted=$( cat $path2logs/blacklisteds | grep ${uuids[$i]} )
		else
			isBlacklisted=""
		fi

		echo "[ ii ] Checking mountpoint..."
		if [ -z $( lsblk -o UUID,MOUNTPOINT | grep "${uuids[$i]}" | awk '/^[A-F0-9_]{4}-[A-F0-9_]{4}\s+$/' ) ] && [ -z $(lsblk -o UUID,MOUNTPOINT | grep "${uuids[$i]}" | awk '/^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\s*$/' ) ]; then
			echo "[ OK ] ${uuids[$i]} is already mounted"
			isMounted=1
		else
			echo "[ ?? ] ${uuids[$i]} is not mounted yet"
			isMounted=0
		fi


		if [ -z "$isBlacklisted" ] && [ $isMounted -eq 0 ]; then
			echo "[ ii ] The device is not in blacklist"
			if [ ! -d /mnt/${uuids[$i]} ]; then
				echo "[ !! ] Could not find directory for ${uuids[$i]}"
				echo "[ !! ] Creating..."
				mkdir /mnt/${uuids[$i]}

				if [ $? -ne 0 ]; then
					echo "[ ER ] Could not create a directory for ${uuids[$i]}"
					echo "[ ER ] Adding to blacklist"
					blacklisteds+=( ${uuids[$i]} )
					continue
				fi
				echo "[ OK ] Success!"
			fi

			echo "[ ii ] Start mounting ${uuids[$i]}..."
			mount "$path2collect${uuids[$i]}" /mnt/"${uuids[$i]}" 
			if [ $? -eq 0 ]; then
				echo "[ OK ] Success!"
				mounteds+=( ${uuids[$i]} )
			else
				echo "[ ER ] Could not mount ${uuids[$i]}"
				echo "[ ER ] Adding to blacklist..."
				blacklisteds+=( ${uuids[$i]} )
			fi
		#elif [ -z $isBlacklisted ] && [ -n $isMounted ]; then
		#	blacklisteds-=( ${uuids[$i]} )

		#	fMounter ${uuids[$i]}
		fi
	done

	FLoger
	FMntCleaner

	sleep .2m
done
