#!/bin/bash -l                                                                       
#===============================================================================        
#                                                                                    
#          FILE: jitsi_NAT_updater.sh                                                            
#                                                                                    
#         USAGE: ./jitsi_NAT_updater.sh                                                          
#                                                                                    
#   DESCRIPTION: set it as a crontab for check if external ip differs from configured ip                         
#       OPTIONS: LOGPATH,LOGFILE,ERRORLOG,SERVICEx,CONFx,DNSNAME                     
#        AUTHOR: Andre Stemmann                                                      
#       CREATED: 06.05.2020 21:47                                                    
#      REVISION: v0.1                                                                
#===============================================================================        
                                                                                      
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin                    
set -o nounset                               # Treat unset variables as an error        
                                                                                      
#===============================================================================        
# BASE VARIABLES                                                                     
#===============================================================================        
                                                                                      
# script vars                                                                        
start=$(date +%s)                                                                    
PROGGI=$(basename "$0")                                                              
                                                                                      
# user vars                                                                          
LOGPATH="/var/log"                                                                   
LOGFILE="${LOGPATH}/syslog"                                                          
ERRORLOG="${LOGPATH}/syslog"                                                         
SERVICE1="jitsi-videobridge2"                                                        
SERVICE2="jicofo"                                                                    
CONF1="/etc/hosts"                                                                   
CONF2="/etc/jitsi/videobridge/sip-communicator.properties"                           
DNSNAME="your.fancy.domain.com"                                                   
                                                                                      
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

function iprenew () {                                                                
     if [ "$realip" != "$confip" ]; then                                              
         log "...configs must updated with new IP $realip"                            
         if sed -i 's/'"$confip"'/'"$realip"'/g' "$CONF1"; then                       
             log "...updated $CONF1 successfully"                                     
         else                                                                         
             errorlog "...Failed to update $CONF1 properly!"                          
             errorlog "...Please re-check manually!"                                  
         fi                                                                           
         if sed -i 's/'"$confip'/'$realip"'/g' "$CONF2"; then                         
             log "...updated $CONF2 successfully"                                     
         else                                                                         
             errorlog "...Failed to update $CONF2 properly"                           
             errorlog "...Please re-check manually!"                                  
         fi                                                                           
     else                                                                             
         log "...everthing is up to date"                                             
     end=$(date +%s)                                                                  
     runtime=$((end-start))                                                           
     log "...Runtime $runtime Seconds"                                                
     exit 0                                                                           
 fi                                                                                   
}                        

# ===============================================================================    
# MAIN RUN                                                                           
# ===============================================================================    
usercheck                                                                            
confip=$(grep "$DNSNAME" /etc/hosts |cut -d" " -f1)                                  
realip=$(dig +short myip.opendns.com @resolver1.opendns.com)                         
log "Jitsi_NAT_Updater Config"                                                       
log "########################"                                                       
log "logfile location    : $LOGFILE"                                                 
log "IP Adress configured: $confip"                                                  
log "Actual IP Address   : $realip"                                                  
iprenew                                                                              
service_restart "$SERVICE2"                                                          
service_restart "$SERVICE1"                                                          
end=$(date +%s)                                                                      
runtime=$((end-start))                                                               
log "...Runtime $runtime Seconds"                                                    
exit 0 
