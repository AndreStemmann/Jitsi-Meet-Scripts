#!/bin/bash -l
#===============================================================================
#
#          FILE: jitsi_backup_push.sh
#
#         USAGE: ./jitsi_backup_push.sh
#
#   DESCRIPTION: simple backups transfer script
#
#       OPTIONS: DSTIP= APP= BACKUPUSER= BACKUPFOLDER=
#        AUTHOR: Andre Stemmann
#  ORGANIZATION: AirITSystems GmbH
#       CREATED: 30.04.2020 10:41
#      REVISION:  v0.2
#===============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
set -o nounset                              # Treat unset variables as an error

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
LOGPATH="${BASEDIR}/jitsi_backup_push_logs"
LOGFILE="${LOGPATH}/${PROGGI}-${TODAY}.log"
ERRORLOG="${LOGPATH}/${PROGGI}-${TODAY}_ERROR.log"
. /etc/os-release

# user vars
DSTIP="192.168.x.x"
APP="jitsi-meet"
BACKUPUSER="myfancybackupuser_to_access_the_remote_host"
BACKUPFOLDER="/var/backups"
BACKUPNAME="${HOST}_${ID}_${VERSION_ID}_${APP}_${TODAY}"
BACKDST="${DSTIP}:${BACKUPFOLDER}/${BACKUPUSER}"

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
		errorlog "...Become user ${BACKUPUSER} and try again"
		exit 1
	fi
}

function folder () {
	if [ ! -d "$1" ]; then
		mkdir -p "$1"
		log "...Create Logfile structure for $PROGGI $1"
	else
		log "...Folder $1 already exists"
	fi
}

function sync () {
	if $(hash rsync); then
		rsync -av --stats --progress "${BACKUPFOLDER}/${BACKUPNAME}.tar.gz" "${BACKUPUSER}"'@'"${BACKDST}"
	else
		errorlog "...Rsync not found, aborting"
	fi
}

function tidyup () {
	find "${BACKUPFOLDER}" -type f -mtime +7 | xargs rm -f
	find "${LOGPATH}/" -type f -mtime +7 | xargs rm -f
}


# ===============================================================================
# MAIN RUN
# ===============================================================================

cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
echo "Backup CONFIG"
echo "#########################"
echo "logfile location   :  $LOGPATH"
echo "backup destination :  $BACKDST"
echo "Backupfile         :  ${BACKUPFOLDER}/$BACKUPNAME"
echo "hostname           :  $HOST"
echo "date               :  $TODAY"
sleep 5
# folder structure
folder "${LOGPATH}"
# script run
usercheck
sync
tidyup
end=$(date +%s)
runtime=$((end-start))
log "...Runtime $runtime Seconds"
exit 0
