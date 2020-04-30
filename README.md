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
```

## License
[MIT](https://choosealicense.com/licenses/mit/)
