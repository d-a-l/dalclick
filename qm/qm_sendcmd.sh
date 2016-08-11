#!/bin/bash
#
# Used to submit jobs to the Queue Manager
# based on Andrew Queue Manager
# http://andrew-hills.blogspot.com.ar/2008/02/simple-bash-based-queue-system.html

ERROR_LOG=/var/tmp/qm_sendcmd.log
QMBNAME=$( basename $0 )

# Check to see if a two parameter has been given
if [ $# != 2 ]
then
	echo "${QMBNAME} $$: ERROR: $# parameter/s has/have been received, expected 2" >> $ERROR_LOG
	exit 1
fi

QUEUEPATH=$1"/.queue"

# Check to see if queue path exist
if [[ ! -d "${QUEUEPATH}" ]]
then
	echo "${QMBNAME} $$: ERROR: Queue path not exist or is not a directory: '$1/.queue'" >> $ERROR_LOG
	exit 1
fi

# Generate vars

LOG=${QUEUEPATH}"/sendcmd_log"
COMMAND=$2
jobid=$(date +%y%m%d%H%M%S)-$(printf "%05d" $RANDOM)

echo "----$(date +%y%m%d%H%M%S)----" >> $LOG

# Create a job file
echo "${COMMAND}" > "${QUEUEPATH}/${jobid}.job"

if [ $? -ne 0 ]
then
		echo "${QMBNAME}: ERROR: Unable to create ${jobid}.job on ${QUEUEPATH}" >> $LOG
		exit 1
fi

echo "${QMBNAME}: job ID ${jobid} assigned" >> $LOG
echo "-----"  >> $LOG

exit 0
