DATABASE_NAME=$(jq -r '.DATABASE_NAME' config.json) # Mongo DB name.
DOMAIN=$(jq -r '.DOMAIN' config.json) # Domain to use for api and database.
MONGO_USER=$(jq -r '.MONGO_USER' config.json) # Mongo DB admin user name.
MONGO_PASS=$(jq -r '.MONGO_PASS' config.json) # Mongo DB admin user pass.
PARSE_DB_PASS=$(jq -r '.PARSE_DB_PASS' config.json) # Password for parse user.

# Import public key.
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10

# Create a List File.
echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list

# Run update before attempting to install packages.
sudo apt-get update

# Install kerberose lib.
sudo apt-get install -y libkrb5-dev

# Install and Verify MongoDB.
sudo apt-get install -y mongodb-org

# Configure MongoDB for Migration.
sudo cat /etc/letsencrypt/archive/$DOMAIN/fullchain1.pem | sudo tee -a /etc/ssl/mongo.pem
sudo cat /etc/letsencrypt/archive/$DOMAIN/privkey1.pem | sudo tee -a /etc/ssl/mongo.pem

sudo chown mongodb:mongodb /etc/ssl/mongo.pem
sudo chmod 600 /etc/ssl/mongo.pem

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

