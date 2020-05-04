#!/bin/bash -
#===============================================================================
#
#          FILE: jitsi_custom_installer.sh
#
#         USAGE: ./jitsi_custom_installer.sh
#
#   DESCRIPTION: little installier script for a custom jitsi installation
#
#       OPTIONS: --USER=admin --PW=admin --DOMAIN=domain.com --BAK=n
#        AUTHOR: Andre Stemmann
#  ORGANIZATION: AirITSystems GmbH
#       CREATED: 04.05.2020 13:39
#      REVISION:  v0.1 - WIP
#===============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
set -o nounset                              # Treat unset variables as an error

# ===============================================================================
# BASE VARIABLES
# ===============================================================================

start=$(date +%s)
TODAY=$(date +%Y%m%d%H)
PROGGI=$(basename "$0")
APP="Jitsi-Meet"
LOGPATH="/var/log"
LOGFILE="${LOGPATH}/syslog"
ERRORLOG="${LOGPATH}/syslog"
APPFOLDER="/opt/jitsi_org_configs"
BACKDST="/var/backups/"
BACKUPROOT="${BACKDST}/${APP}_backup_${TODAY}"
BACKUPROOT2="${BACKDST}/${APP}_backup_generic_configs_${TODAY}"

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
	echo "---------------------------------------------"
	echo "--USER=<string>   : Jitsi Username"
	echo "--PW=<string>     : Jitsi User Password"
	echo "--DOMAIN=<string> : Jitsi Domain to use"
	echo "--BAK=boolean     : Use config from backup y/n"
	echo "----------------------------------------------"
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
	echo "--BAK=<boolean>   : Whether to install from scratch or use a backup as config source"
	echo ""
}

function parseparams () {
	if [ $# -eq 0 ] ; then
		echo
		echo "no parameters are given!"
		echo
		usage
		exit 1
	fi
	if [ "$1" == "-h" ]; then
		printHelp
		exit 0
	fi
	if [ "$1" == "--help" ]; then
		printHelp
		exit 0
	fi
	until [[ ! "$*" ]]; do
		if [[ ${1:0:2} = '--' ]]; then
			PAIR="${1:2}"
			PARAMETER=$(echo "${PAIR%=*}" | tr '[:lower:]' '[:upper:]')
			eval P_"$PARAMETER"="${PAIR##*=}"
		fi
		shift
	done
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

function service_stop () {
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

function service_start () {
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

function createuser () {
	if ! prosodyctl register "${P_USER}" "${P_DOMAIN}" "${P_PW}"; then
		errorlog "please re-check user account creation manually, something went wrong"
		exit 1
	fi
}

function backup () {
	rsync -avz --relative --log-file="${LOGFILE}" "${APPFOLDER}" "${BACKUPROOT}"
}

function symlinker () {
	cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
	cd "$1" || errorlog "...failed to cd into $1"
	sourcefiles=($(find . -maxdepth 5 -type f))
	for i in "${sourcefiles[@]}"
	do
		j=${i/\./}
		k=${j/_org/}
		rsync -avz --relative --remove-source-files "${k}" "${BACKUPROOT2}/"
		mv "${BACKUPROOT2}""${k}" "${BACKUPROOT2}""${k}_BAK"
		l=$(realpath "$i")
		ln -s "${l}" "${k}"
	done
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

function instfback () {
	# Installation from config Backup-File
	apt update && apt upgrade -y
	apt install nginx -y
	echo 'deb https://download.jitsi.org stable/' >> /etc/apt/sources.list.d/jitsi-stable.list
	wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
	apt update && apt install jitsi-meet -y
	/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
	ufw allow http
	ufw allow https
	ufw allow 10000/udp
	service_stop "jicofo"
	service_stop "jitsi-videobridge2"
	service_stop "prosody"
	symlinker "./jitsi"
	symlinker "./prosody"
	grantrights_jitsi "./jitsi"
	grantrights_prosody "./prosody"
	createuser
}

function instfs () {
	# Installation from scratch with custom configs
	apt update && apt upgrade -y
	apt install nginx -y
	echo 'deb https://download.jitsi.org stable/' >> /etc/apt/sources.list.d/jitsi-stable.list
	wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
	apt update && apt install jitsi-meet -y
	/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
	ufw allow http
	ufw allow https
	ufw allow 10000/udp
	service_stop "jicofo"
	service_stop "jitsi-videobridge2"
	service_stop "prosody"
	backup
	symlinker "./jitsi"
	symlinker "./prosody"
	grantrights_jitsi "./jitsi"
	grantrights_prosody "./prosody"
	createuser
	sed  "s/your.fancy.domain/${DOMAIN}/g" "/etc/jitsi/meet/${DOMAIN}-config.js"
	sed  "s/your.fancy.domain.com/${DOMAIN}/g" | sed  "s/JICOFO_SECRET/$(grep -e '^JICOFO_SECRET=.*' /etc/jitsi/jicofo/config | cut -d '=' -f2)/g" | sed  "s/TURN_SECRET/$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-8})/g" "/etc/prosody/conf.avail/${DOMAIN}.cfg.lua"
	sed -i "s/your.fancy.domain.com/${DOMAIN}/g" "sip-communicator.properties_org"
}

# ===============================================================================
# MAIN RUN
# ===============================================================================

cd "$BASEDIR" || errorlog "...failed to cd into $BASEDIR"
echo "jitsi custom installer config"
echo "#############################"
echo "logfile location   :  $LOGFILE"
echo "user to create     :  $USER"
echo "domain to use      :  $DOMAIN"
sleep 3
usercheck
distrocheck
parseparams "$@"
folder "$BACKUPROOT"
case "$P_BAK" in
	[yY]*)
		instfback;;
	[nN]*)
		instfs;;
esac
service_start "jicofo"
service_start "jitsi-videobridge2"
service_start "prosody"
end=$(date +%s)
runtime=$((end-start))
log "...Runtime $runtime Seconds"
exit 0
