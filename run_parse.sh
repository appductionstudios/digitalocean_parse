# Execute while logged in as root.

if ! [ $(id -u) = 0 ]; then
   echo "$(tput bold)$(tput setaf 1)Script must be executed as root.$(tput sgr0)"
   exit 1
fi

# Add Mongo before updating to avoid updating multiple times.

# Import public key.
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10

# Create a List File.
echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list

# Run update before attempting to install packages.
sudo apt-get update

# Install jq to read from config file.
sudo apt-get install -y jq

# Set variables:
DOMAIN=$(jq -r '.DOMAIN' config.json) # Domain to use for api and database.
PARSE_DB_PASS=$(jq -r '.PARSE_DB_PASS' config.json) # Password for parse user.
SWAPSIZE=$(jq -r '.SWAPSIZE' config.json) # Swapsize for Ubuntu machine.
USERNAME=$(jq -r '.USERNAME' config.json) # Name of user to ssh to your Ubuntu machine with.
PASSWORD=$(jq -r '.PASSWORD' config.json) # Password of user to ssh to your Ubuntu machine with.
PARSE_USER_PASSWORD=$(jq -r '.PARSE_USER_PASSWORD' config.json) # Password of dedicated parse user.
EMAIL_ADDRESS=$(jq -r '.EMAIL_ADDRESS' config.json) # Email address to use with letsencrypt.

DATABASE_NAME=$(jq -r '.DATABASE_NAME' config.json) # Mongo DB name.
MONGO_USER=$(jq -r '.MONGO_USER' config.json) # Mongo DB admin user name.
MONGO_PASS=$(jq -r '.MONGO_PASS' config.json) # Mongo DB admin user pass.

APP_NAME=$(jq -r '.APP_NAME' config.json) # App name on parse-dashboard
APPLICATION_ID=$(jq -r '.APPLICATION_ID' config.json) # Application ID for Parse app to migrate.
MASTER_KEY=$(jq -r '.MASTER_KEY' config.json) # Master Key for Parse app to migrate.

DASHBOARD_USERNAME=$(jq -r '.DASHBOARD_USERNAME' config.json) # Username to login to parse-dashboard with.
DASHBOARD_PASSWORD=$(jq -r '.DASHBOARD_PASSWORD' config.json) # Password to login to parse-dashboard with.

TIMEZONE=$(jq -r '.TIMEZONE' config.json) # Timezone to use. Enter it as <continent>/<city>. For example: America/New_York

# (Optional): Set up cloud code.
CLOUD_REPO_TYPE=$(jq -r '.CLOUD_REPO_TYPE' config.json) # Set to either "hg" or "git".
CLOUD_REPO_LINK=$(jq -r '.CLOUD_REPO_LINK' config.json) # Command/URL to run after git clone or hg clone.
CLOUD_PATH=$(jq -r '.CLOUD_PATH' config.json) # Path of cloud folder within repository. If files are already on repo root level enter ".".
PRE_CLOUD_SCRIPT=$(jq -r '.PRE_CLOUD_SCRIPT' config.json) # Path to a shell script, that may install any missing requirements before installing your cloud code.

# (Optional): Set up email adapter.
VERIFY_EMAIL=$(jq -r '.VERIFY_EMAIL' config.json) # Set to true to verify emails. Defaults to false.
PREVENT_UNVERIFIED_EMAIL_LOGIN=$(jq -r '.PREVENT_UNVERIFIED_EMAIL_LOGIN' config.json) # Set to true to prevent login with unverified emails. Defaults to false.
EMAIL_ADAPTER_MODULE=$(jq -r '.EMAIL_ADAPTER_MODULE' config.json) # Choose email adapter. Defaults to mailgun. Checkout more options here: https://github.com/ParsePlatform/parse-server#email-verification-and-password-reset
EMAIL_FROM_ADDRESS=$(jq -r '.EMAIL_FROM_ADDRESS' config.json) # Address to send verification and reset emails from.
EMAIL_DOMAIN=$(jq -r '.EMAIL_DOMAIN' config.json) # Domain on your email provider to use.
EMAIL_API_KEY=$(jq -r '.EMAIL_API_KEY' config.json) # Api key provided by your email provider.

# 1. Create User.
useradd --create-home --system $USERNAME -p $(perl -e "print crypt($PASSWORD,'sa');") -g sudo

# Open configuration file as root. Change PermitRootLogin to no.
sudo sed -i '/PermitRootLogin yes/c\PermitRootLogin no' /etc/ssh/sshd_config

# Reload ssh service.
service ssh restart

# 2. Server Config.
# Setup firewall.
sudo ufw allow ssh
sudo ufw --force enable
ufw allow 443
ufw allow 27017

# Configure timezones.
sudo timedatectl set-timezone $TIMEZONE

# Configure NTP synchronization.
sudo apt-get install -y ntp

# Create swap file.
sudo fallocate -l $SWAPSIZE /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

# 3. Install MongoDB.

# Install kerberose lib.
sudo apt-get install -y libkrb5-dev

# Install and Verify MongoDB.
sudo apt-get install -y mongodb-org

# Check everything is working.
service mongod status

# 4. Parse Server.
# Change dir to root folder.
cd ~

# Install latest Node.js.
curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
sudo apt-get install -y nodejs build-essential git

# Install Let's Encrypt and Dependencies.
sudo apt-get -y install git bc
sudo git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
cd /opt/letsencrypt

# Retrieve Initial Certificate
sudo ./letsencrypt-auto -d $DOMAIN certonly --standalone --email $EMAIL_ADDRESS --agree-tos
# Configure MongoDB for Migration.
sudo cat /etc/letsencrypt/archive/$DOMAIN/fullchain1.pem | sudo tee -a /etc/ssl/mongo.pem
sudo cat /etc/letsencrypt/archive/$DOMAIN/privkey1.pem | sudo tee -a /etc/ssl/mongo.pem

sudo chown mongodb:mongodb /etc/ssl/mongo.pem
sudo chmod 600 /etc/ssl/mongo.pem

# Install Cron.
sudo apt-get -y install cron

# Set Cron Job for auto renewal every Monday at 2:30. Restart Nginx every Monday at 2:35.
echo "30 2 * * 1 /opt/letsencrypt/letsencrypt-auto renew >> /var/log/le-renew.log\n35 2 * * 1 /etc/init.d/nginx reload" > tempcron
sudo crontab tempcron
rm tempcron

# Create Mongo Admin user.
echo "use admin
db.createUser({user: \"$MONGO_USER\",pwd: \"$MONGO_PASS\", roles: [{role: \"userAdminAnyDatabase\", db: \"admin\"}]})
exit" > mongo_admin.js
mongo --port 27017 < mongo_admin.js
rm mongo_admin.js

# Configure MongoDB for migration.
echo "use $DATABASE_NAME
db.createUser({user: \"parse\",pwd: \"$PARSE_DB_PASS\", roles: [\"readWrite\", \"dbAdmin\"]})
exit" > mongo_parse.js
mongo --port 27017 < mongo_parse.js
rm mongo_parse.js

# Update mongod.conf file.
sudo sed -i "/bindIp: 127.0.0.1/c\  bindIp: 0.0.0.0\n  ssl:\n    mode: requireSSL\n    PEMKeyFile: /etc/ssl/mongo.pem" /etc/mongod.conf
sudo sed -i '/#security/c\security:\n  authorization: enabled' /etc/mongod.conf
echo "setParameter:\n  failIndexKeyTooLong: false" >> /etc/mongod.conf

# Restart MongoDB.
sudo service mongod restart

# Install and configure Nginx
sudo apt-get install -y nginx

sudo echo "# HTTP - redirect all requests to HTTPS
server {
    listen 80;
    listen [::]:80 default_server ipv6only=on;
    return 301 https://$host$request_uri;
}
# HTTPS - serve HTML from /usr/share/nginx/html, proxy requests to /parse/
# through to Parse Server
server {
        listen 443;
        server_name $DOMAIN;
        root /usr/share/nginx/html;
        index index.html index.htm;
        ssl on;
        # Use certificate and key provided by Let's Encrypt:
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;
        ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
        # Pass requests for /parse/ to Parse Server instance at localhost:1337
        location /parse/ {
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-NginX-Proxy true;
                proxy_pass http://localhost:1337/parse/;
                proxy_ssl_session_reuse off;
                proxy_set_header Host \$http_host;
                proxy_redirect off;
        }
        location /dashboard/ {
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-NginX-Proxy true;
                proxy_pass https://localhost:4040/dashboard/;
                proxy_ssl_session_reuse off;
                proxy_set_header Host \$http_host;
                proxy_redirect off;
        }
        location / {
                try_files \$uri \$uri/ =404;
        }
}" > /etc/nginx/sites-enabled/default

sudo service nginx restart

# PARSE DASHBOARD
# Install parse-dashboard
npm install -g parse-dashboard

# Create Dedicated Parse User
useradd --create-home --system parse -p $(perl -e "print crypt($PARSE_USER_PASSWORD,'sa');")

# Pull cloud code repo, if any.
if [ "$CLOUD_REPO_LINK" != "" ] ; then
  if [ "$CLOUD_REPO_TYPE" = "hg" ] ; then
      sudo apt-get install -y mercurial
      hg clone $CLOUD_REPO_LINK /home/parse/cloud_dir
  else
      git clone $CLOUD_REPO_LINK /home/parse/cloud_dir
  fi
  ln -s /home/parse/cloud_dir/$CLOUD_PATH /home/parse/cloud
else
  echo "No cloud code repo supplied."
fi

if [ "$PRE_CLOUD_SCRIPT" != "" ] ; then
  sudo sh /home/parse/cloud_dir/$PRE_CLOUD_SCRIPT
fi

# Install Parse Server and PM2
sudo npm install -g parse-server pm2

# @TODO figure out why it fails with watch=true.
echo "{
  \"apps\" : [{
    \"name\"        : \"parse-server-wrapper\",
    \"script\"      : \"/usr/bin/parse-server\",
    \"watch\"       : false,
    \"merge_logs\"  : true,
    \"cwd\"         : \"/home/parse\",
    \"env\": {
      \"PARSE_SERVER_CLOUD_CODE_MAIN\": \"/home/parse/cloud/main.js\",
      \"PARSE_SERVER_DATABASE_URI\": \"mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true\",
      \"PARSE_SERVER_APPLICATION_ID\": \"$APPLICATION_ID\",
      \"PARSE_SERVER_MASTER_KEY\": \"$MASTER_KEY\",
      \"PARSE_PUBLIC_SERVER_URL\": \"https://$DOMAIN/parse\",
      \"PARSE_SERVER_MOUNT_PATH\": \"/parse\",
      \"VERBOSE\": \"1\"
    }
  }, {
    \"name\"        : \"parse-dashboard-wrapper\",
    \"script\"      : \"/usr/bin/parse-dashboard\",
    \"watch\"       : false,
    \"merge_logs\"  : true,
    \"cwd\"         : \"/home/parse\",
    \"env\": {
      \"PARSE_DASHBOARD_SERVER_URL\": \"https://$DOMAIN/parse\",
      \"PARSE_DASHBOARD_APP_ID\": \"$APPLICATION_ID\",
      \"PARSE_DASHBOARD_APP_NAME\": \"$APP_NAME\",
      \"PARSE_DASHBOARD_MASTER_KEY\": \"$MASTER_KEY\",
      \"PARSE_DASHBOARD_SSL_KEY\": \"/etc/letsencrypt/live/$DOMAIN/privkey.pem\",
      \"PARSE_DASHBOARD_SSL_CERT\": \"/etc/letsencrypt/live/$DOMAIN/fullchain.pem\",
      \"PARSE_DASHBOARD_USER_ID\": \"$DASHBOARD_USERNAME\",
      \"PARSE_DASHBOARD_USER_PASSWORD\": \"$DASHBOARD_PASSWORD\",
      \"PORT\": \"4040\",
      \"MOUNT_PATH\": \"/dashboard\"
    }
  }]
}" > /home/parse/ecosystem.json

# If email is setup add email adapter to ecosystem.json.
if [ "$VERIFY_EMAIL" = true ] ; then
  if [ "$EMAIL_FROM_ADDRESS" != "" ] && [ "$EMAIL_DOMAIN" != "" ] && [ "$EMAIL_API_KEY" != ""  ] ; then
    sudo sed -i "/\"VERBOSE\": \"1\"/c\\
      \"VERBOSE\": \"1\",\n\
      \"PARSE_SERVER_APP_NAME\": \"$APP_NAME\",\n\
      \"PARSE_SERVER_VERIFY_USER_EMAILS\": true,\n\
      \"PARSE_SERVER_EMAIL_ADAPTER\": {\n\
          \"module\": \"$EMAIL_ADAPTER_MODULE\",\n\
              \"options\": {\n\
                \"fromAddress\": \"$EMAIL_FROM_ADDRESS\",\n\
                \"domain\": \"$EMAIL_DOMAIN\",\n\
                \"apiKey\": \"$EMAIL_API_KEY\"\n\
          }\n\
      },\n\
      \"PARSE_SERVER_PREVENT_LOGIN_WITH_UNVERIFIED_EMAIL\": true" /home/parse/ecosystem.json
  else
    echo "$(tput bold)$(tput setaf 1)Must set EMAIL_FROM_ADDRESS, EMAIL_DOMAIN and EMAIL_API_KEY in config.json in order to verify emails.$(tput sgr0)"
  fi
fi

# Run the script with pm2.
pm2 start /home/parse/ecosystem.json

# Save pm2 process.
pm2 save

# Run initialization scripts as parse user.
sudo pm2 startup ubuntu -u root --hp /root/

# Ouptut migration string:
echo "Use the following string for migration: $(tput bold)mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true$(tput sgr0)"

