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

## License
[MIT](https://choosealicense.com/licenses/mit/)
