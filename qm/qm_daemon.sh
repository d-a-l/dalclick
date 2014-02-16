#!/bin/bash
#
# Queue Manager
# based on Andrew basic queue manager for running jobs remotely
# http://andrew-hills.blogspot.com.ar/2008/02/simple-bash-based-queue-system.html

QMBNAME=$( basename $0 )
ERROR_LOG=/var/tmp/qm_daemon_$$.log
# Check to see if one parameter has been given

if [ $# != 1 ]
then
	echo " ${QMBNAME}: ERROR: $# parameter/s has/have been received, expected 1" >> $ERROR_LOG
	exit 1
fi

# Check to see if queue path exist
if [[ ! -d $1 ]]
then
	echo " ${QMBNAME}: ERROR: Queue path not exist or is not a directory: '$1'" >> $ERROR_LOG
	exit 1
else
	QUEUEPATH=$1"/.queue"
fi

if [[ -e "${QUEUEPATH}" ]] # another qm maybe here
then
    # Check if another queue manager is running for this queuepath
    if [[ -e "${QUEUEPATH}/qmpid" ]] # another qm maybe here
    then
	    PID=$( cat "${QUEUEPATH}/qmpid" )
	    if [[ ${PID} != "" ]]
	    then
		    CHECKPID=$( ps -p ${PID} -o cmd= | grep "${QMBNAME}" | grep "${QUEUEPATH}" )
		    if [[ "$CHECKPID" != "" ]] # the process is qm
		    then
			    echo " ${QMBNAME} ABORTED: Another queue manager is running in this queuepath: '${QUEUEPATH}', pid: ${PID}, pid paths: ${CHECKPID}"  >> /var/tmp/qm_daemon.log
			    exit 1
		    fi
	    fi
	    echo " ${QMBNAME}: WARNING: Maybe another queue manager was aborted abnormally?" >> $ERROR_LOG
	    echo "   queuepath: '${QUEUEPATH}', pid: '${PID}', pid paths: '${CHECKPID}'" >> $ERROR_LOG
	    rm -f "${QUEUEPATH}/.qmpid"
    fi
else
    mkdir "${QUEUEPATH}"
fi

LOG="${QUEUEPATH}/daemon_log"

echo "----$(date +%y%m%d%H%M%S)----" >> $LOG

# TIMEOUT=300 # 10m
# count=0

# save actual pid
echo " ${QMBNAME}: actual pid: $$" >> $LOG
echo -n "$$" > "${QUEUEPATH}/.qmpid"

# Ensure a commands to quit doesn't already exist
# that commands are sending after jobs sending are finished
rm -f "${QUEUEPATH}/quit"
rm -f "${QUEUEPATH}/quit_if_empty"

echo " ${QMBNAME}: Queue Manager Initialising..." >> $LOG
echo '   Entering looping state...' >> $LOG
echo ' ' >> $LOG

while
true # Loop forever
do
	# Check to see if there are jobs
	ls "${QUEUEPATH}" | grep .job > "${QUEUEPATH}/.filelist"
	nextjob=$(head -1 "${QUEUEPATH}/.filelist")
	# Then check to see if there's something in this variable. If not, then there's not job to run
	if [[ ! -z $nextjob ]]
	then
		# There's a job to run
		echo " ${QMBNAME}: Job ${nextjob%%.job} Started" >> $LOG

		# Run the job in a new bash shell
		bash "${QUEUEPATH}/$nextjob"

		# Job complete tell user

		# Now Job is complete. Remove the file
		rm -f "${QUEUEPATH}/${nextjob}"
		echo " ${QMBNAME}: Job ${nextjob%%.job} Finished" >> $LOG
		# set timeout counter to 0 when There's a new job to run
		# count=0
	else
		# There's no job to run
		if [[ -e "${QUEUEPATH}/quit_if_empty" ]]
		then
			if [[ -O "${QUEUEPATH}/quit_if_empty" ]]
			then
				echo " ${QMBNAME}: Quit file if empty detected. The Queue Manager is shutting down..." >> $LOG
				rm -f "${QUEUEPATH}/quit_if_empty"
				break
			else
				echo " ${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file" >> $LOG
				rm -f "${QUEUEPATH}/quit_if_empty"
			fi
		fi

		# sleep for 2 seconds
		sleep 2
		# timeout counter
		# $(( count++ ))
	fi

	# Need to check for the quit.job file and
	# confirm that the owner is whoami
	if [[ -e "${QUEUEPATH}/quit" ]]
	then
		if [[ -O "${QUEUEPATH}/quit" ]]
		then
			echo " ${QMBNAME}: Quit file detected. The Queue Manager is shutting down..." >> $LOG
			rm -f "${QUEUEPATH}/quit"
			break
		else
			echo " ${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file" >> $LOG
			rm -f "${QUEUEPATH}/quit"
		fi
	fi

	# if (( $count >= $TIMEOUT ))
	# 	echo ' Timeout detected. The Queue Manager is shutting down...'
	# 	break
	# fi

done

# Clean-up dir
rm -f "${QUEUEPATH}/.filelist"
rm -f "${QUEUEPATH}/.qmpid"

echo " ${QMBNAME}: Clean-up complete. Queue Manager finished." >> $LOG
echo "-----"  >> $LOG

