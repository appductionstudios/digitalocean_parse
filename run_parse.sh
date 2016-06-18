# Execute while logged in as root.

# Set variables:
DOMAIN="" # Domain to use for api and database.
PARSE_DB_PASS="" # Password for parse user.
SWAPSIZE="" # Swapsize for Ubuntu machine.
USERNAME="" # Name of user to ssh to your Ubuntu machine with.
PASSWORD="" # Password of user to ssh to your Ubuntu machine with.
PARSE_USER_PASSWORD="" # Password of dedicated parse user.
EMAIL_ADDRESS="" # Email address to use with letsencrypt.

DATABASE_NAME="" # Mongo DB name.
MONGO_USER="" # Mongo DB admin user name.
MONGO_PASS="" # Mongo DB admin user pass.

APP_NAME="" # App name on parse-dashboard
APPLICATION_ID="" # Application ID for Parse app to migrate.
MASTER_KEY="" # Master Key for Parse app to migrate.

DASHBOARD_USERNAME="" # Username to login to parse-dashboard with.
DASHBOARD_PASSWORD="" # Password to login to parse-dashboard with.

TIMEZONE="" # Timezone to use. Enter it as <continent>/<city>. For example: America/New_York

# (Optional)
CLOUD_REPO_TYPE="" # Set to either "hg" or "git".
CLOUD_REPO_LINK="" # Command/URL to run after git clone or hg clone.
CLOUD_PATH="" # Path of cloud folder within repository. If files are already on repo root level enter ".".
PRE_CLOUD_SCRIPT="" # Path to a shell script, that may install any missing requirements before installing your cloud code.

# @TODO: Make sure all variables are set.


# 1. Create User.
echo "$PASSWORD\n$PASSWORD\n" | sudo adduser $USERNAME

# Add user to root group.
sudo gpasswd -a $USERNAME sudo

# Open configuration file as root. Change PermitRootLogin to no.
sudo sed -i '/PermitRootLogin yes/c\PermitRootLogin no' /etc/ssh/sshd_config

# Reload ssh service.
service ssh restart

# 2. Server Config.
# Setup firewall.
sudo ufw allow ssh
sudo ufw --force enable
ufw allow 443
ufw allow 4040
ufw allow 27017

# Configure timezones.
sudo timedatectl set-timezone $TIMEZONE

# Configure NTP synchronization.
sudo apt-get update
sudo apt-get install -y ntp

# Create swap file.
sudo fallocate -l $SWAPSIZE /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

# 3. Install MongoDB.
# Import public key.
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10

# Create a List File.
echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list
sudo apt-get update

# Install and Verify MongoDB.
sudo apt-get install -y mongodb-org

# Check everything is working.
service mongod status

# 4. Parse Server.
# Change dir to root folder.
cd ~

# Install latest Node.js.
curl -sL https://deb.nodesource.com/setup_5.x -o nodesource_setup.sh
sudo -E bash ./nodesource_setup.sh
sudo apt-get install -y nodejs build-essential git

# Install Example Parse Server App.
git clone https://github.com/ParsePlatform/parse-server-example.git /root/parse-server-example
cd ~/parse-server-example
npm install

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
sudo apt-get update
sudo apt-get -y install cron

# Set Cron Job for auto renewal every Monday at 2:30. Restart Nginx every Monday at 2:35.
echo -e "30 2 * * 1 /opt/letsencrypt/letsencrypt-auto renew >> /var/log/le-renew.log\n35 2 * * 1 /etc/init.d/nginx reload" > tempcron
sudo crontab tempcron
rm tempcron

# Create Mongo Admin user.
echo "use admin
db.createUser({user: \"$MONGO_USER\",pwd: \"$MONGO_PASS\", roles: [{role: \"userAdminAnyDatabase\", db: \"admin\"}]})
exit" > mongo_admin.js
mongo --port 27017 < mongo_admin.js
rm mongo_admin.js

# Configure MongoDB for migration.
mongo --port 27017 --ssl --sslAllowInvalidCertificates --authenticationDatabase admin --username $MONGO_USER --password $MONGO_PASS
echo "use $DATABASE_NAME
db.createUser({user: \"parse\",pwd: \"$PARSE_DB_PASS\", roles: [\"readWrite\", \"dbAdmin\"]})
exit" > mongo_parse.js
/
mongo --port 27017 < mongo_parse.js
rm mongo_parse.js

# Update mongod.conf file.
cp ./mongod.conf /etc/mongod.conf

# Restart MongoDB.
sudo service mongod restart

# Install Parse Server and PM2
sudo npm install -g parse-server pm2

# Create Dedicated Parse User
sudo useradd --create-home --system parse
echo "$PARSE_USER_PASSWORD\n$PARSE_USER_PASSWORD\n" | sudo passwd parse

# @TODO WHY IS THIS LINE "SUDO SU PARSE CD ~" COMMENTED?
# sudo su parse
# cd ~

mkdir -p /home/parse/cloud

# @TODO: copy from cloud folder.

echo "{
  \"apps\" : [{
    \"name\"        : \"parse-wrapper\",
    \"script\"      : \"/usr/bin/parse-server\",
    \"watch\"       : true,
    \"merge_logs\"  : true,
    \"cwd\"         : \"/home/parse\",
    \"env\": {
      \"PARSE_SERVER_CLOUD_CODE_MAIN\": \"/home/parse/cloud/main.js\",
      \"PARSE_SERVER_DATABASE_URI\": \"mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true\",
      \"PARSE_SERVER_APPLICATION_ID\": \"$APPLICATION_ID\",
      \"PARSE_SERVER_MASTER_KEY\": \"$MASTER_KEY\",
    }
  }]
}" > /home/parse/ecosystem.json

# Run the script with pm2.
pm2 start /home/parse/ecosystem.json

# Save pm2 process.
pm2 save

# # Exit to regular sudo user.
# @TODO WHY IS THIS LINE "EXIT" COMMENTED?
# exit

# Run initialization scripts as parse user.
sudo pm2 startup ubuntu -u parse --hp /home/parse/

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
                # proxy_set_header X-Real-IP $remote_addr;
                # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-NginX-Proxy true;
                proxy_pass http://localhost:1337/parse/;
                proxy_ssl_session_reuse off;
                # proxy_set_header Host $http_host;
                proxy_redirect off;
        }

        location / {
                try_files $uri $uri/ =404;
        }
}" > /etc/nginx/sites-enabled/default

sudo service nginx restart

# PARSE DASHBOARD
# Install parse-dashboard
npm install -g parse-dashboard

# Write parse-dashboard config file.
echo "{
  \"apps\": [
    {
      \"serverURL\": \"https://$DOMAIN/parse\",
      \"appId\": \"$APPLICATION_ID\",
      \"masterKey\": \"$MASTER_KEY\",
      \"appName\": \"$APP_NAME\"
    }
  ],
  \"users\": [
    {
      \"user\":\"$DASHBOARD_USERNAME\",
      \"pass\":\"$DASHBOARD_PASSWORD\"
    }
  ]
}" > /home/parse/parse-dashboard.config

# @TODO SSL is not working yet
# parse-dashboard --config parse-dashboard.config --sslKey /etc/letsencrypt/archive/a.beitify.com/privkey1.pem
parse-dashboard --config /home/parse/parse-dashboard.config --allowInsecureHTTP&

# Update index.js with database uri.
cd /root/parse-server-example/
sed -i "s/mongodb:\/\/localhost:27017\/dev/mongodb:\/\/parse:$PARSE_DB_PASS@$DOMAIN:27017\/$DATABASE_NAME?ssl=true/g" /root/parse-server-example/index.js
sed -i "/appId:/c\  appId: \"$APPLICATION_ID\"," /root/parse-server-example/index.js
sed -i "/masterKey:/c\  masterKey: \"$MASTER_KEY\"," /root/parse-server-example/index.js
sed -i '/serverURL:/a\  publicServerURL: "https://'"$DOMAIN"'/parse",' /root/parse-server-example/index.js

# Pull cloud code repo, if any.
if [ "$CLOUD_REPO_LINK" != "" ] ; then
  if [ "$CLOUD_REPO_TYPE" = "hg" ] ; then
      sudo apt-get install -y mercurial
      hg clone $CLOUD_REPO_LINK /root/cloud_dir
  else
      git clone $CLOUD_REPO_LINK /root/cloud_dir
  fi
  cd /root/cloud_dir/$CLOUD_PATH
  cp * /root/parse-server-example/cloud
else
  echo "No cloud code repo supplied."
fi

if [ "$PRE_CLOUD_SCRIPT" != "" ] ; then
  sudo sh /root/cloud_dir/$PRE_CLOUD_SCRIPT
fi

# Run parse server example.
cd /root/parse-server-example/
npm start&

# Ouptut migration string:
echo "Use the following string for migration: $(tput bold)mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true$(tput sgr0)"
