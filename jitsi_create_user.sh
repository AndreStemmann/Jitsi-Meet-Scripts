#!/bin/bash -
#===============================================================================
#
#          FILE: jitsi_create_user.sh
#
#         USAGE: ./jitsi_create_user.sh
#
#   DESCRIPTION: bash-wrapper for prosody user creation and user backup
#
#       OPTIONS: --USER=jack --PW=1234 --DOMAIN=my.domain.com --BAK=y
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

start=$(date +%s)
TODAY=$(date +%Y%m%d%H)
PROGGI=$(basename "$0")
APP="Prosody"
LOGPATH="/var/log"
LOGFILE="${LOGPATH}/syslog"
ERRORLOG="${LOGPATH}/syslog"
APPFOLDER="/var/lib/prosody"
BACKDST="/var/backups/"
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

function usage () {
	echo "jitsi create user"
	echo "-----------------"
	echo "mandatory parameter:"
	echo "----------------------------------------"
	echo "--USER=<string>   : Jitsi Username"
	echo "--PW=<string>     : Jitsi User Password"
	echo "--DOMAIN=<string> : Jitsi Domain to use"
	echo "--BAK=boolean     : Backup Config y/n"
	echo "----------------------------------------"
	echo "-h or --help for more information"
}

function printHelp () {
	echo "These are the parameters needed to call the script"
	echo "------------------------------------------------------------------------------------"
	echo "--USER=<string>   : The free chosen username you want to provide"
	echo "                    e.g. pangalacticthunderuser01"
	echo ""
	echo "--PW=<string>     : User secret pass"
	echo "                    use a simple passphrase, its more secure than your avg. password"
	echo ""
	echo "--DOMAIN=<string> : The plain stripped Jitsi domain"
	echo "                    e.g. my.chattool.com"
	echo ""
	echo "--BAK=<boolean>   : Whether to backup existing prosody accounts or not"
	echo "                    /var/lib/prosody/ will be rsynced to $BACKDST"
}

function parseparams () {
	# catch an empty call
	if [ $# -eq 0 ] ; then
		echo
		echo "no parameters are given!"
		echo
		usage
		exit 1
	fi

	# print help text
	if [ "$1" == "-h" ]; then
		printHelp
		exit 0
	fi
	if [ "$1" == "--help" ]; then
		printHelp
		exit 0
	fi

	# parse parameters
	until [[ ! "$*" ]]; do
		if [[ ${1:0:2} = '--' ]]; then
			PAIR="${1:2}"
			PARAMETER=$(echo "${PAIR%=*}" | tr '[:lower:]' '[:upper:]')
			eval P_"$PARAMETER"="${PAIR##*=}"
		fi
		shift
	done

	# parameter re-check
	if   [ -z "$P_USER" ] ; then
		errorlog "ERROR: please specify the USER - parameter"
		errorlog "exiting script..."
		exit 1
	elif [ -z "$P_PW" ] ; then
		errorlog "ERROR: please specify the PW - parameter"
		errorlog "exiting script..."
		exit 1
	elif [ -z "$P_DOMAIN" ] ; then
		errorlog "ERROR: please specify the DOMAIN - parameter"
		errorlog "exiting script..."
		exit 1
	elif [ -z "$P_BAK" ] ; then
		errorlog "ERROR: please specify the BAK - parameter"
		errorlog "exiting script..."
		exit 1
	fi
}

function service_restart () {
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

	systemctl start "$1"
	sleep 3
	if systemctl is-active --quiet "$1"; then
		log "...$1 is safe and sound"
	else
		errorlog "...Failed to start $1"
		errorlog "...Trying it again"
		systemctl start "$1"
		sleep 3
		if systemctl is-active --quiet "$1"; then
			log "...$1 is safe and sound"
		else
			errorlog "...Failed to start $1"
			errorlog "...CRITICAL - check manually"
		fi
	fi
}

function restartq () {
	echo "In order to register the new user correctly, the services"
	echo "jicofo, jitsi-videobridge and prosody must be restartet"
	while true; do
		read -rp "Do you wish to restart all related services now? [y/n]" yn
		case $yn in
			[Yy]* )
				service_restart jicofo;
				service_restart jitsi-videobridge2;
				service_restart prosody;
				break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

function createuser () {
	# create prosody user
	if ! prosodyctl register "${P_USER}" "${P_DOMAIN}" "${P_PW}"; then
		errorlog "please re-check user account creation manually, something went wrong"
		exit 1
	fi
}

function backup () {
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER}" "${BACKUPROOT}"
}

# ===============================================================================
# MAIN RUN
# ===============================================================================
usercheck
distrocheck
parseparams "$@"
case "$P_BAK" in
	[yY]*)
		backup
		;;
esac
createuser
restartq
end=$(date +%s)
runtime=$((end-start))
log "...Runtime $runtime Seconds"
exit 0
