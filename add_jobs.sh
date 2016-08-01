DOMAIN=$(jq -r '.DOMAIN' config.json) # Domain to use for api and database.
PARSE_DB_PASS=$(jq -r '.PARSE_DB_PASS' config.json) # Password for parse user.
DATABASE_NAME=$(jq -r '.DATABASE_NAME' config.json) # Mongo DB name.
APPLICATION_ID=$(jq -r '.APPLICATION_ID' config.json) # Application ID for Parse app to migrate.
TIMEZONE=$(jq -r '.TIMEZONE' config.json) # Timezone to use. Enter it as <continent>/<city>. For example: America/New_York
EXTERNAL_MONGODB_URI=$(jq -r '.EXTERNAL_MONGODB_URI' config.json) # External MongoDB Uri.

if [ "$EXTERNAL_MONGODB_URI" = "" ] ; then
  MONGODB_URI="mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true"
else
  MONGODB_URI="$EXTERNAL_MONGODB_URI"
fi

cd /home/parse

# Prepare for background jobs using agenda.
# Install agenda.
npm install agenda

# Create jobs.js file.
echo "var Agenda = require('agenda');

var mongoConnectionString = '$MONGODB_URI';
var agenda = new Agenda({db: {address: mongoConnectionString}});

// Asks Agenda to check for new tasks every minute.
agenda.processEvery('1 minute');

var Parse = require('/usr/lib/node_modules/parse-server/node_modules/parse/node');
Parse.initialize(process.env.AGENDA_JOBS_APPLICATION_ID);
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
});" > /home/parse/jobs.js

# # Start agenda jobs with index.js.
sed -i '/}]/c\\
  },\n\
  {\n\
    "name"        : "parse-jobs-wrapper",\n\
    "script"      : "/home/parse/jobs.js",\n\
    "watch"       : false,\n\
    "merge_logs"  : true,\n\
    "cwd"         : "/home/parse",\n\
    "env": {\n\
      "AGENDA_JOBS_APPLICATION_ID": "$APPLICATION_ID"\n\
    }\n\
  }]' /home/parse/ecosystem.json

pm2 restart /home/parse/ecosystem.json

# Save pm2 process.
pm2 save

# Run initialization scripts as parse user.
sudo pm2 startup ubuntu -u root --hp /root/
