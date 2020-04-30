#!/bin/bash -
#===============================================================================
#
#          FILE: jitsi_backup.sh
#
#         USAGE: ./jitsi_backup.sh
#
#   DESCRIPTION: simple jitsi config backups script
#
#       OPTIONS: APP= SERVICEx= APPFOLDER= BACKDST=
#        AUTHOR: Andre Stemmann
#       CREATED: 30.04.2020 10:41
#===============================================================================

set -o nounset                              # Treat unset variables as an error
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# ===============================================================================
# BASE VARIABLES
# ===============================================================================
# script vars
TODAY=$(date +%Y%m%d)
start=$(date +%s)
HOST=$(hostname -f)
PROGGI=$(basename "$0")
READLINK=$(readlink -f "$0")
BASEDIR=$(dirname "$READLINK")
LOGPATH="${BASEDIR}/jitsi_backup_logs"
LOGFILE="${LOGPATH}/${PROGGI}-${TODAY}.log"
ERRORLOG="${LOGPATH}/${PROGGI}-${TODAY}_ERROR.log"

# user vars
APP="jitsi-meet"
SERVICE1="nginx"
SERVICE2="jicofo"
SERVICE3="jitsi-videobridge2"
APPFOLDER1="/etc/jitsi"
APPFOLDER2="/etc/${SERVICE1}"
APPFOLDER3="/opt/jitsi_tools"
APPFOLDER4="/etc/prosody"
BACKDST="/var/backups"
BACKUPROOT="${BACKDST}/${APP}_backup_${TODAY}"

# ===============================================================================
# BASE FUNCTIONS
# ===============================================================================
function log () {
	echo "$PROGGI ; $(date '+%Y%m%d %H:%M:%S') ; $@" | tee -a "${LOGFILE}"
}

function errorlog () {
	echo "${PROGGI}_ERRORLOG ; $(date '+%Y%m%d %H:%M:%S') ; $@" | tee -a "${ERRORLOG}"
}

function usercheck () {
	if [[ $UID -ne 0 ]]; then
		errorlog "...Become user root and try again"
		exit 1
	fi
}

function folder () {
	if [ ! -d "$1" ]; then
		mkdir -p "$1"
		log "...Create Backupfolder structure for $APP $1"
	else
		log "...Folder $1 already exists"
	fi
}

function distrocheck () {
	if [[ -r /etc/os-release ]]; then
		. /etc/os-release
		if [[ $ID = ubuntu ]]; then
			log  "...Running ${ID}_${VERSION_ID} "
			BACKUPNAME="${HOST}"_"${ID}"_"${VERSION_ID}"_"${APP}"_"${TODAY}"
			folder "${BACKUPROOT}"
		else
			errorlog "...Not running an debian based distribution. ID=$ID, VERSION=$VERSION"
			BACKUPNAME="${HOST}"_"${ID}"_"${VERSION_ID}"_"${APP}"_"${TODAY}"
			folder "${BACKUPROOT}"
		fi
	else
		errorlog "...$APP is not running a distribution with /etc/os-release available"
		errorlog "...Please perform backup manually"
		exit 1
	fi
}

function service_off () {
	systemctl is-active --quiet $1
	if [ $? -eq 0 ]; then
		log "...Graceful stopping $1"
		systemctl stop $1
		sleep 10
	else
		log "...service $1 already stopped"
		systemctl is-active --quiet $1
		if [ $? -ne 0 ]; then
			log "...service $1 stopped"
		else
			log "...service $1 still running, trying to SIGTERM it now"
			kill -15 $APP
			sleep 10
			systemctl is-active --quiet $1
			if [ $? -ne 0 ]; then
				log "...service $1 stopped"
			else
				log "...service $1 still running, trying to SIGKILL it now"
				kill -9 $1
				sleep 10
			fi
		fi
	fi
}

function backup_flatfiles () {
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER1}" "${BACKUPROOT}"
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER2}" "${BACKUPROOT}"
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER3}" "${BACKUPROOT}"
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER4}" "${BACKUPROOT}"
}

function service_on () {
	log "...restarting service $1"
	systemctl start $1
	sleep 10
	systemctl is-active --quiet $1
	if [ $? -eq 0 ]; then
		log "...$1 is safe and sound"
	else
		errorlog "...Failed to start $1"
		errorlog "...Trying it again"
		systemctl start $1
		sleep 10
		systemctl is-active --quiet $1
		if [ $? -eq 0 ]; then
			log "...$1 is safe and sound"
		else
			errorlog "...Failed to start $1"
			errorlog "...CRITICAL - check manually"
		fi
	fi
}

function zipper () {
	log "...Will pack all found sourcefiles as tar.gz archive"
	cd "$BACKDST"
	log "Found Backup Files to zip:"
	log "$(find . -type d -name "*_backup_${TODAY}*")"
	find . -type d -name "*_backup_${TODAY}*" | xargs tar -cvzf "${BACKUPNAME}".tar.gz
	if [ $? -ne 0 ]; then
		errorlog "...Failed to create tar.gz-archive from sourcefiles"
		exit 1
	fi
}

function tidyup () {
	rm -rf "${BACKUPROOT}"
	log "...removed unpacked backupfiles under $BACKUPROOT"
	find "${LOGPATH}/" -type f -mtime +7 | xargs rm -f
}

# MAIN RUN
# ===============================================================================
# BASIC SETUP
# ===============================================================================
cd "$BASEDIR"
echo "Backup CONFIG"
echo "#########################"
echo "logfile location   :  $LOGPATH"
echo "backup destination :  $BACKDST"
echo "hostname           :  $HOST"
echo "date               :  $TODAY"
sleep 5
# folder structure
folder "${LOGPATH}"
# script run
usercheck
distrocheck
if [ -f "${BACKUPNAME}".tar.gz ]; then
	log "...Backupfile already exists"
	log "...See /var/log/syslog or ${BASEDIR}/jitsi_backup_logs"
	exit 0
else
	log "...First backup for today, proceeding"
	sleep 3
	service_off $SERVICE1
	service_off $SERVICE2
	service_off $SERVICE3
	backup_flatfiles
	service_on $SERVICE3
	service_on $SERVICE2
	service_on $SERVICE1
	zipper
	tidyup
fi
end=$(date +%s)
runtime=$((end-start))
log "...Runtime $runtime Seconds"
exit 0
