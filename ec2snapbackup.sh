#!/bin/bash
# Author:  John Antreassian
# Date:    01/05/2014
# Description: The purpose of this script is to manage snapshots ONLY for the volumes attached to the instance,
#	       which this script is running on.
#  Todo:   Add flag for turning on verbose 
#          add flag for outputting status to a file (useful for Nagios to read from) 

source ~/.bash_profile
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
SERVER_NAME=""
# RETENTION is the number of days to keep snapshots
RETENTION_DAYS=3
REGION=us-east-1

which ec2-describe-volumes > /dev/null
X=$?
if [ "$X" != "0" ]
then
	echo "ERROR: ec2-describe-volumes command was not found on this system"
	exit $X
fi

TODAY=`date +%s`
RETENTION_UNIXTIME=`expr $RETENTION_DAYS \* 24 \* 60 \* 60`
TMP_VFILE=/tmp/ec2snapshot-volumes.tmp
TMP_SFILE=/tmp/ec2snapshot-snapshots.tmp
rm -f $TMP_VFILE
rm -f $TMP_SFILE

#1. Get the instance ID of the EC2 instance the script is running on.
INSTANCE_ID=`curl -s http://169.254.169.254/1.0/meta-data/instance-id`
X=$?
if [ "$X" != "0" ] && [ "$INSTANCE_ID" != "" ];
then
	echo "ERROR: Something went wrong when trying to find the ID of the instance this script is running on."
	exit $X
fi
echo "Instance ID detected as $INSTANCE_ID"
#2. Find the volumes attached to the EC2 Instance the script is running on.
ec2-describe-volumes -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY --region $REGION | grep $INSTANCE_ID > $TMP_VFILE
VOLUME_LIST=$(cat $TMP_VFILE | awk '{print $2}')

#3. Create a snapshot of the volumes attached to the EC2 Instance we are running on.
sync
echo $VOLUME_LIST
for volume in $(echo $VOLUME_LIST); do
   NAME=$(cat $TMP_VFILE | grep $volume | awk '{ print $3"_"$2 }')
   DESC=$SERVER_NAME"_"$NAME-$(date +%y%m%d%H%M%S)
   echo "Creating Snapshot for the volume: $volume with description: $DESC"
   ec2-create-snapshot -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY --region $REGION -d $DESC $volume
echo ""
   # We run ec2-describe-snapshots in this for loop becuase we only want to gather a list of volumes associated with this instance
   ec2-describe-snapshots -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY --region $REGION  | grep $volume >> $TMP_SFILE
done


#4. Remove snapshots older than RETENTION days.
SNAPSHOT_LIST=$(cat $TMP_SFILE | awk '{print $2}')
for snapshot in $(echo $SNAPSHOT_LIST); do 
echo "Snapshot is $snapshot"
	stime=$(cat /tmp/ec2snapshot-snapshots.tmp | grep $snapshot | awk {'print $5}' | awk -F"T" '{print $1,$2}' | awk -F"+" '{print $1}' )
	# Convert the date/time to Unix time format.
	stime=`date -d "$stime" +%s`
	difftime=`expr $TODAY - $stime`
	if [ $difftime -ge $RETENTION_UNIXTIME ];
	then
		echo "Snapshot $snapshot is past its retention time and will now be deleted."
		ec2-delete-snapshot -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY --region $REGION $snapshot
		X=$?
		if [ "$X" != "0" ]
		then
			echo "Warning: Something went wrong when trying to delete snapshot id $snapshot"
		fi
	fi
done 
