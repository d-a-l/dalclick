#!/bin/bash
#
# Used to submit jobs to the Queue Manager
# based on Andrew Queue Manager
# http://andrew-hills.blogspot.com.ar/2008/02/simple-bash-based-queue-system.html

ERROR_LOG=/var/tmp/qm_sendcmd.log
QMBNAME=$( basename $0 )
QMBNAME='[PPM Send]'

THISDIR="$(dirname "$0")"
cd "$THISDIR"

# Check to see if a two parameter has been given
if [ $# != 1 ]
then
	echo "${QMBNAME} $$: ERROR: $# parameter/s has/have been received, expected 1" >> $ERROR_LOG
	echo "${QMBNAME} $$: ERROR: $# parameter/s has/have been received, expected 1"
	exit 1
fi

if [[ -f "../CONFIG" ]]
 then
  . ../CONFIG
else
  echo
  echo " Necesita crear el archivo 'CONFIG' en '$THISDIR/'"
  echo " con la configuración de directorios de su proyecto."
  echo " Renombre el archivo 'CONFIG.example' y reemplace las rutas"
  echo " que considere necesarias."
  echo
  echo " Presione <enter> para salir."
  echo -n " >>"
  read tecla
  exit 0
fi

[[ -d $DALCLICK_PROJECTS ]] || { echo "ERROR: la carpeta de proyectos '$DALCLICK_PROJECTS' no existe, revise la configuracion de directorios."; exit 0; }

QUEUEPATH=$DALCLICK_PROJECTS"/.queue"
echo
echo "${QMBNAME}: Enviando trabajo a: '$QUEUEPATH'"

# Check to see if queue path exist
# if [[ ! -d "${QUEUEPATH}" ]]
# then
#	echo "${QMBNAME} $$: ERROR: Queue path not exist or is not a directory: '$1/.queue'" >> $ERROR_LOG
#	exit 1
# fi

# Generate vars

LOG=${QUEUEPATH}"/sendcmd_log"
COMMAND=$1
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
echo "${QMBNAME}: Nuevo trabajo '${jobid}' en cola para procesar!"
echo 
echo "-----"  >> $LOG

exit 0
