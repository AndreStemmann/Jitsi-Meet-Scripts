# Jitsi Conflinker
is a script to keep your jitsi-meet configs update-proof.
It will symlink your configs from another folder to the original destination.
In case of an update, just re-deploy your configs with this script.
## Installation
### Prerequisites
Every Appfolder represents in it the absolute path of the original files
This step must be done manually (rsync /etc/jitsi /opt/jitsi_tools etc...)
Rename your rsynced config files with an trailing _org
The script will compile an backup of the original configfiles and store them
in a manner that the corresponding backup-script can compute it.
Deploy the script in an appropriate folder and copy your live configs as follows
```bash
root@server:/opt/jitsi_tools# ls
README.md  conflinker.sh  jitsi  nginx  prosody
````
Every folder represents the absolute config path e.g.
```bash
root@server:/opt/jitsi-custom-configs-source# find . -type f
./nginx/etc/nginx/sites-available/your.fancy.domain.com.conf_org
./jitsi/etc/jitsi/videobridge/logging.properties_org
./jitsi/etc/jitsi/videobridge/20-jvb-udp-buffers.conf_org
./jitsi/etc/jitsi/videobridge/config_org
./jitsi/etc/jitsi/videobridge/sip-communicator.properties_org
./jitsi/etc/jitsi/jicofo/logging.properties_org
./jitsi/etc/jitsi/jicofo/config_org
./jitsi/etc/jitsi/jicofo/sip-communicator.properties_org
./jitsi/etc/jitsi/meet/your.jitsi.server-config.js_org
./jitsi/etc/sysctl.d/99-custom.conf_org
./jitsi/usr/share/jitsi-meet/interface_config.js_org
./jitsi/usr/share/jitsi-meet/title.html_org
./jitsi/usr/share/jitsi-meet/static/welcomePageAdditionalContent.html_org
./jitsi/usr/share/jitsi-meet/css/all.css_org
./jitsi/usr/share/jitsi-meet/libs/app.bundle.min.js_org
./jitsi/usr/share/jitsi-meet/libs/dial_in_info_bundle.min.js_org
./jitsi/usr/share/jitsi-meet/lang/main-de.json_org
./prosody/etc/prosody/conf.avail/your.fancy.domain.com.cfg.lua_org
```
## Usage
```bash
./conflinker
```
## Explanation
After running the script you'll find a backup of the original files in your configured backup path.
Symbolic links are in place of the original files you deployed before to your custom remote folder.

# Jitsi-Backup Scripts
It is a simple backup script to fetch all configs and store them aside

## Installation
Deploy the script in an appropriate location and configure it to your needs
```bash
mkdir -p /root/backup_jobs/
cp jitsi_backup.sh !$
cp jitsi_backup_push.sh /root/backup_jobs/
crontab -l
# Jitsi Backup Job. runtime ~ 45 Sec.
5 4 * * * /root/backup_jobs/jitsi_backup.sh
# Jitsi copy to Coldstorage. Runtime ~15 Sec.
10 4 * * * /root/backup_jobs/nt4_jitsi_backup_push.sh
```
## Usage
```bash
./jitsi_backup.sh
./jitsi_backup_push.sh
```
# Jitsi Create User Script
It is a simple wrapper-script to create a new prosody user on your behalf, restart the services as needed and backup the existing config

## Installation
Deploy the script in an appropriate location and configure it to your needs
```bash
mkdir -p /opt/jitsi_tools/
cp jitsi_create_user.sh !$
```
## Usage
```bash
./jitsi_create_user.sh --USER=jack --PW=1234 --DOMAIN=my.fancy.domain.com --BAK=y


## License
[MIT](https://choosealicense.com/licenses/mit/)
