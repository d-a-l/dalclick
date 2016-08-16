#!/bin/bash
#
# Queue Manager
# based on Andrew basic queue manager for running jobs remotely
# http://andrew-hills.blogspot.com.ar/2008/02/simple-bash-based-queue-system.html

# QMBNAME=$( basename $0 )

echo
echo
echo " ==== Bienvenido al Gestor de Post-procesado ===="
echo

THISDIR="$(dirname "$0")"
cd "$THISDIR"

if [[ -f "../CONFIG" ]]
 then
  . ../CONFIG
else
  echo
  echo " Necesita crear el archivo 'CONFIG' en '$DALCLICK_SCRIPTS_DIR/'"
  echo " con la configuración de directorios de su proyecto."
  echo " Renombre el archivo 'CONFIG.example' y reemplace las rutas"
  echo " que considere necesarias."
  echo
  echo " Presione <enter> para salir."
  echo -n " >>"
  read tecla
  exit 0
fi

[[ -d $DALCLICK_PROJECTS ]] || { echo " ERROR: la carpeta de proyectos '$DALCLICK_PROJECTS' no existe, revise la configuracion de directorios."; exit 0; }

QUEUEPATH=$DALCLICK_PROJECTS"/.queue"

QMBNAME='[Gestor]'
ERROR_LOG=/var/tmp/qm_daemon_$$.log

echo " ${QMBNAME}: Leyendo cola de trabajos desde: '$QUEUEPATH'"

# Check to see if one parameter has been given

# if [ $# != 1 ]
# then
# 	echo "${QMBNAME}: ERROR: Se recibieron $# parámetro/s, se esperaba 1 (ruta a la cola de archivos)" >> $ERROR_LOG
# 	exit 1
# fi

# Check to see if queue path exist
# if [[ ! -d $1 ]]
# then
# 	echo "${QMBNAME}: ERROR: La ruta a la cola de archivos no existe o no es un directorio: '$1'" >> $ERROR_LOG
# 	exit 1
# else
# 	QUEUEPATH=$1"/.queue"
# fi

if [[ -e "${QUEUEPATH}" ]] # another qm maybe here
then
    echo -n " ${QMBNAME}: Verificando si otro gestor está ejecutando esta cola de archivos..."
    if [[ -e "${QUEUEPATH}/qmpid" ]] # another qm maybe here
    then
	    PID=$( cat "${QUEUEPATH}/qmpid" )
	    if [[ ${PID} != "" ]]
	    then
		    CHECKPID=$( ps -p ${PID} -o cmd= | grep "${QMBNAME}" | grep "${QUEUEPATH}" )
		    if [[ "$CHECKPID" != "" ]] # the process is qm
		    then
                echo "TERMINAR"
			    echo " ${QMBNAME} TERMINAR: Otro gestor de post procesado está ejecutando esta cola de archivos: '${QUEUEPATH}', pid: ${PID}, pid paths: ${CHECKPID}"  >> /var/tmp/qm_daemon.log
			    echo " ${QMBNAME} Otro gestor de post procesado está ejecutando esta cola de archivos: '${QUEUEPATH}', pid: ${PID}, pid paths: ${CHECKPID}"
			    exit 1
		    fi
	    fi
	    echo "OK"
	    echo "${QMBNAME}: ATENCION: ¿Quizá otro gestor de post procesado se canceló anormalmente?" >> $ERROR_LOG
	    echo "${QMBNAME}: ATENCION: ¿Quizá otro gestor de post procesado se canceló anormalmente?"
	    echo "   queuepath: '${QUEUEPATH}', pid: '${PID}', pid paths: '${CHECKPID}'" >> $ERROR_LOG
	    echo "   queuepath: '${QUEUEPATH}', pid: '${PID}', pid paths: '${CHECKPID}'"
	    rm -f "${QUEUEPATH}/.qmpid"
	else
	    echo "OK"
    fi
else
    mkdir "${QUEUEPATH}"
fi

LOG="${QUEUEPATH}/daemon_log"

echo "----$(date +%y%m%d%H%M%S)----" >> $LOG

# TIMEOUT=300 # 10m
# count=0

# save actual pid
echo "${QMBNAME}: actual pid: $$" >> $LOG
echo -n "$$" > "${QUEUEPATH}/.qmpid"

# Ensure a commands to quit doesn't already exist
# that commands are sending after jobs sending are finished
rm -f "${QUEUEPATH}/quit"
rm -f "${QUEUEPATH}/quit_if_empty"

echo -n " ${QMBNAME}: Buscando trabajos previos pendientes en cola..."

EXISTING_JOBS=$(ls -d "${QUEUEPATH}"/* | grep .job)

if [ ! -z "$EXISTING_JOBS" ]
 then
    echo 
    echo
    i=0
    while read -r line
    do
        if [ ! -z "$line" ]
         then
            i=$((i + 1))
            JOBNAME=$(basename $line)
            PROJPATH=$(cat "$line" | cut -d " " -f 2)
            PROJNAME=$(cat "$line" | cut -d " " -f 2 | xargs basename )
            EVENIMG=$(ls "$PROJPATH/pre/even" | wc -w)
            FINISHED=$(ls "$PROJPATH/done" | grep .pdf | wc -w)
            ODDIMG=$(ls "$PROJPATH/pre/odd" | wc -w)
            IMGS=$(( EVENIMG + ODDIMG ))
            if (( FINISHED > 0 ))
             then
                FWARN="## YA FUE POSTPROCESADO ##"
            else
                FWARN=""
            fi
            printf " [%s] '%s' %s capturas %s\n" "$JOBNAME" "$PROJNAME" "$IMGS" "$FWARN"
        fi
    done <<< "$EXISTING_JOBS"
else
 echo "OK"
fi

if (( i > 0 ))
 then
    echo
    echo " Hay $i trabajo/s pendientes para procesar!"
    echo
    echo " Opciones:"
    echo 
    echo "  [enter] Comenzar procesar los trabajos pendientes inmediatamente."
    echo "  [x]     Eliminar los trabajos pendientes listados y esperar nuevos."
    echo "  [q]     Salir sin hacer nada."
    echo
    read -p ">> " option
    case "$option" in
        "")
            echo " Procesando..."
            ;;
        x)
            echo " ${QMBNAME}: Eliminando trabajos anteriores..."
            echo "${QMBNAME}: Se seleccionó remover archivos en cola pervia" >> $LOG
            ls -d "${QUEUEPATH}"/* | grep .job | xargs rm -v
            ;;
        *) 
            echo " ${QMBNAME}: Eligió salir"
            exit 0
            ;;
    esac
else
    echo "${QMBNAME}: No hay archivos pendientes para procesar" >> $LOG
    echo " (No hay archivos pendientes para procesar)"
fi

#exit 0

echo "${QMBNAME}: Queue Manager Initialising..." >> $LOG
echo '   Entering looping state...' >> $LOG
echo ' ' >> $LOG
echo 

echo 
echo " ${QMBNAME}: Iniciando loop de espera..."
echo " ${QMBNAME}: (Para salir use Ctrl+C)"
echo

while
true # Loop forever
do
    echo -en "\r [LOOP]: Leyendo..." 
	# Check to see if there are jobs...
	ls "${QUEUEPATH}" | grep .job > "${QUEUEPATH}/.filelist"
	nextjob=$(head -1 "${QUEUEPATH}/.filelist")
	# Then check to see if there's something in this variable. If not, then there's not job to run
	if [[ ! -z $nextjob ]]
	then
	    echo
        echo
		echo " ${QMBNAME}: Leído un nuevo trabajo en la cola para ser ejecutado!"
		echo "${QMBNAME}: Job ${nextjob%%.job} Started" >> $LOG
		echo " ${QMBNAME}: Ejecutando..."
		echo
		echo "- - - - - - INICIO ${nextjob} - - - - - - "
		echo
		
		bash "${QUEUEPATH}/$nextjob"

        echo
		echo "- - - - - - FIN ${nextjob}  - - - - - - - "
		echo
		echo " ${QMBNAME}: Trabajo terminado"

		echo " ${QMBNAME}: Eliminar trabajo ya ejecutado de la lista"
		rm -f "${QUEUEPATH}/${nextjob}"
		echo "${QMBNAME}: Job ${nextjob%%.job} Finished" >> $LOG
		echo " ${QMBNAME}: ${nextjob} Eliminado"
		# set timeout counter to 0 when There's a new job to run
		# count=0
		echo 
	else
		# There's no job to run
        sleep 1
		if [[ -e "${QUEUEPATH}/quit_if_empty" ]]
		then
			if [[ -O "${QUEUEPATH}/quit_if_empty" ]]
			then
				echo "${QMBNAME}: Quit file if empty detected. The Queue Manager is shutting down..." >> $LOG
				echo " ${QMBNAME}: Quit file if empty detected. The Queue Manager is shutting down..."
				rm -f "${QUEUEPATH}/quit_if_empty"
				break
			else
				echo "${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file" >> $LOG
				echo " ${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file"
				rm -f "${QUEUEPATH}/quit_if_empty"
			fi
		fi

		# sleep for 5 seconds
		ESPERA=5
		clear=""
  		echo -en "\r [LOOP]: Esperando ${ESPERA}s "
		for (( c=1;c<=ESPERA;c++ ))
        do
    		sleep 1
            echo -n "."
    		clear=$clear" "
		done
		sleep 0.2
		echo -en "\r [LOOP]:              $clear"
		
		# timeout counter
		# $(( count++ ))
	fi

	# Need to check for the quit.job file and
	# confirm that the owner is whoami
	if [[ -e "${QUEUEPATH}/quit" ]]
	then
		if [[ -O "${QUEUEPATH}/quit" ]]
		then
		    echo
			echo "${QMBNAME}: Quit file detected. The Queue Manager is shutting down..." >> $LOG
			echo " ${QMBNAME}: Quit file detected. The Queue Manager is shutting down..."
			rm -f "${QUEUEPATH}/quit"
			break
		else
		    echo
			echo "${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file" >> $LOG
			echo " ${QMBNAME}: WARNING: Owner of file different to `whoami`. Removing file"
			rm -f "${QUEUEPATH}/quit"
		fi
	fi

	# if (( $count >= $TIMEOUT ))
	# 	echo ' Timeout detected. The Queue Manager is shutting down...'
	# 	break
	# fi

done

echo
echo " ${QMBNAME}: Clean-up dir"
rm -f "${QUEUEPATH}/.filelist"
rm -f "${QUEUEPATH}/.qmpid"

echo "${QMBNAME}: Clean-up complete. Queue Manager finished." >> $LOG
echo " ${QMBNAME}: Clean-up complete. Queue Manager finished."
echo "-----"  >> $LOG
echo

