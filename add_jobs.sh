DOMAIN=$(jq -r '.DOMAIN' config.json) # Domain to use for api and database.
PARSE_DB_PASS=$(jq -r '.PARSE_DB_PASS' config.json) # Password for parse user.
DATABASE_NAME=$(jq -r '.DATABASE_NAME' config.json) # Mongo DB name.
APPLICATION_ID=$(jq -r '.APPLICATION_ID' config.json) # Application ID for Parse app to migrate.
TIMEZONE=$(jq -r '.TIMEZONE' config.json) # Timezone to use. Enter it as <continent>/<city>. For example: America/New_York

cd /root/parse-server-example

# Prepare for background jobs using agenda.
# Install agenda.
npm install agenda

# Create jobs.js file.
echo "var Agenda = require('agenda');

var mongoConnectionString = 'mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true';
var agenda = new Agenda({db: {address: mongoConnectionString}});

// Asks Agenda to check for new tasks every minute.
agenda.processEvery('1 minute');

var Parse = require('parse/node');
Parse.initialize('$APPLICATION_ID');
Parse.serverURL = 'http://localhost:1337/parse';

agenda.define('myScheduledTask', function(job, done) {
    // Your code here. For example:
    // var myClass = Parse.Object.extend('myClass');
    // var obj = new myClass();
    // obj.set('attr', 'myval');
    // obj.save();
    console.log('Running scheduled task ...');
    done();
});

agenda.on('ready', function() {
  agenda.every('5 minutes', 'myScheduledTask', {}, {
    timezone: '$TIMEZONE'
  });

  // Alternatively, you could also do:
  // agenda.every('*/5 * * * *', 'myScheduledTask', {}, {
  //  timezone: '$TIMEZONE'
  //});

  agenda.start();
});" > jobs.js

# # Start agenda jobs with index.js.
sed -i '/var path/a\var jobs = require("./jobs");' /root/parse-server-example/index.js

pm2 restart parse-server-wrapper
