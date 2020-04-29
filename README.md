# Jitsi Conflinker

is a script to keep your jitsi-meet configs update-proof.
It will symlink your configs from another folder to the original destination. 
In case of an update, just re-deploy your configs with this script.

## Installation

Deploy the script in an appropriate folder and copy your live configs as follows

```bash
root@server:/opt/jitsi-custom-configs-source# ls
README.md  conflinker.sh  jitsi  nginx  prosody
````
Every folder represents the absolute config path e.g.
```bash
root@server:/opt/jitsi-custom-configs-source# find . -type f
./nginx/etc/nginx/sites-available/your.jitsi.server.conf
./jitsi/etc/jitsi/videobridge/logging.properties
./jitsi/etc/jitsi/videobridge/20-jvb-udp-buffers.conf
./jitsi/etc/jitsi/videobridge/config
./jitsi/etc/jitsi/videobridge/sip-communicator.properties
./jitsi/etc/jitsi/jicofo/logging.properties
./jitsi/etc/jitsi/jicofo/config
./jitsi/etc/jitsi/jicofo/sip-communicator.properties
./jitsi/etc/jitsi/meet/your.jitsi.server-config.js
./jitsi/etc/sysctl.d/99-custom.conf
./jitsi/usr/share/jitsi-meet/interface_config.js
./jitsi/usr/share/jitsi-meet/title.html
./jitsi/usr/share/jitsi-meet/static/welcomePageAdditionalContent.html
./jitsi/usr/share/jitsi-meet/css/all.css
./jitsi/usr/share/jitsi-meet/libs/app.bundle.min.js
./jitsi/usr/share/jitsi-meet/libs/dial_in_info_bundle.min.js
./jitsi/usr/share/jitsi-meet/lang/main-de.json
./prosody/etc/prosody/conf.avail/your.fancy.domain.de.cfg.lua
```

## Usage

```bash
./conflinker
```
## License
[MIT](https://choosealicense.com/licenses/mit/)
