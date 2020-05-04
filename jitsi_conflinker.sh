#!/bin/bash -
#===============================================================================
#
#          FILE: jitsi_conflinker.sh
#
#         USAGE: ./jitsi_conflinker.sh
#
#   DESCRIPTION: backup relevant sourcefiles and symlink customized configs instead
#
#       OPTIONS: adapt variables as needed
#  REQUIREMENTS: run as root
#        AUTHOR: Andre Stemmann
#  ORGANIZATION: AirITSystems GmbH
#       CREATED: 20.04.2020 16:42
#      REVISION: v0.2
#===============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
set -o nounset  # Treat unset variables as an error

# ===============================================================================
# BASE VARIABLES
# ===============================================================================

# script vars
start=$(date +%s)
TODAY=$(date +%Y%m%d%H)
PROGGI=$(basename "$0")
READLINK=$(readlink -f "$0")
BASEDIR=$(dirname "$READLINK")

# user vars
LOGPATH="/var/log"
LOGFILE="${LOGPATH}/syslog"
ERRORLOG="${LOGPATH}/syslog"
APP="jitsi-meet-conflinker"
SERVICE1="jitsi-videobridge2"
SERVICE2="nginx"
SERVICE3="jicofo"
SERVICE4="prosody"
BACKDST="/var/backups"
BACKUPROOT="${BACKDST}/${APP}_backup_${TODAY}"

# ===============================================================================
# BASE FUNCTIONS
# ===============================================================================

function log () {
	echo "$PROGGI ; $(date '+%Y%m%d %H:%M:%S') ; $*" | tee -a "${LOGFILE}"
}

function errorlog () {
	echo "${PROGGI}_ERRORLOG ; $(date '+%Y%m%d %H:%M:%S') ; $*" | tee -a "${ERRORLOG}"
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
		log "...Create Backupfolder structure for $APP original configs $1"
	else
		log "...Folder $1 already exists"
	fi
}

function distrocheck () {
	if [[ -r /etc/os-release ]]; then
		. /etc/os-release
		if [[ $ID = ubuntu ]]; then
			log  "...Running ${ID}_${VERSION_ID} "
			folder "${BACKUPROOT}"
		else
			errorlog "...Not running an debian based distribution. ID=$ID, VERSION=$VERSION"
			folder "${BACKUPROOT}"
		fi
	else
		errorlog "...$APP is not running a distribution with /etc/os-release available"
		errorlog "...Please perform backup manually"
		exit 1
	fi
}

function service_off () {
	if systemctl is-active --quiet "$1"; then
		log "...stopping $1"
		systemctl stop "$1"
		sleep 3
	else
		log "...service $1 already stopped"
		if ! systemctl is-active --quiet "$1"; then
			log "...service $1 stopped"
		else
			log "...service $1 still running, trying to SIGTERM it now"
			kill -15 "$1"
			sleep 3
			if ! systemctl is-active --quiet "$1"; then
				log "...service $1 stopped"
			else
				log "...service $1 still running, trying to SIGKILL it now"
				kill -9 "$1"
				sleep 3
			fi
		fi
	fi
}

function symlinker () {
	cd "$BASEDIR" || errorlog "failed to cd into $BASEDIR"
	cd "$1" || errorlog "failed to cd into $1"
	# find files for reference in local repo, store them in array
	# e.g. ./etc/jitsi/videobridge/20-jvb-udp-buffers.conf_org
	sourcefiles=($(find . -maxdepth 5 -type f))
	for i in "${sourcefiles[@]}"
	do
		# clean leading dot on elements
		# e.g. /etc/jitsi/videobridge/20-jvb-udp-buffers.conf_org
		j=${i/\./}
	 	# clean trailling _org on source repo files
		# e.g. /etc/jitsi/videobridge/20-jvb-udp-buffers.conf
		k=${j/_org/}
		# rsync original file to backup-location
		# e.g. rsync /etc/jitsi/videobridge/20-jvb-udp-buffers.conf /var/backups/jitsi-meet_backup_20200427/
		rsync -avz --relative --remove-source-files "${k}" "${BACKUPROOT}/"
		# rename backed up file to *_BAK
		# e.g. /var/backups/jitsi-meet_backup_20200427/etc/jitsi/videobridge/20-jvb-udp-buffers.conf_BAK
		mv "${BACKUPROOT}""${k}" "${BACKUPROOT}""${k}_BAK"
		# gather absolute path from sourcefile
		# /opt/jitsi-custom-configs/jitsi/etc/jitsi/videobridge/20-jvb-udp-buffers.conf
		l=$(realpath "$i")
		# /opt/jitsi-custom-configs/jitsi/etc/jitsi/videobridge/20-jvb-udp-buffers.conf /etc/jitsi/videobridge/20-jvb-udp-buffers.conf
		ln -s "${l}" "${k}"
	done
}

function service_on () {
	systemctl start "$1"
	sleep 3
	if systemctl is-active --quiet "$1"; then
		log "...$1 is safe and sound"
	else
		errorlog "...Failed to start $1"
		errorlog "...Trying it again"
		systemctl start "$1"
		sleep 3
		if ! systemctl is-active --quiet "$1"; then
			log "...$1 is safe and sound"
		else
			errorlog "...Failed to start $1"
			errorlog "...CRITICAL - check manually"
		fi
	fi
}

function grantrights_jitsi () {
	cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
	cd "$1" || errorlog "...failed to cd into $1"
	PWDIR=$(pwd "$1")
	chown -R jicofo:jitsi "${PWDIR}"/etc/jitsi/jicofo
	chown -R jvb:jitsi "${PWDIR}"/etc/jitsi/videobridge
	chown -R jicofo:jitsi /etc/jitsi/jicofo
	chown -R jvb:jitsi /etc/jitsi/videobridge
}

function grantrights_prosody () {
	cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
	cd "$1" || errorlog "...failed to cd into $1"
	PWDIR=$(pwd "$1")
	chown -R root:prosody "${PWDIR}"/etc/prosody
	chown -R root:prosody /etc/prosody
}

# ===============================================================================
# MAIN RUN
# ===============================================================================

cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
echo "Symlink Jitsi Configs"
echo "#########################"
echo "logfile location   :  $LOGFILE"
sleep 3
usercheck
distrocheck
folder "$BACKUPROOT"
service_off $SERVICE2
service_off $SERVICE1
service_off $SERVICE3
service_off $SERVICE4
symlinker "./jitsi"
symlinker "./prosody"
grantrights_jitsi "./jitsi"
grantrights_prosody "./prosody"
service_on $SERVICE1
service_on $SERVICE3
service_on $SERVICE4
service_on $SERVICE2
end=$(date +%s)
runtime=$((end-start))
log "...Runtime $runtime Seconds"
exit 0
