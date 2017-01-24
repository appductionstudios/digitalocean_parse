DOMAIN=$(jq -r '.DOMAIN' config.json) # Domain to use for api and database.
PARSE_DB_PASS=$(jq -r '.PARSE_DB_PASS' config.json) # Password for parse user.
DATABASE_NAME=$(jq -r '.DATABASE_NAME' config.json) # Mongo DB name.
APPLICATION_ID=$(jq -r '.APPLICATION_ID' config.json) # Application ID for Parse app to migrate.
MASTER_KEY=$(jq -r '.MASTER_KEY' config.json)
TIMEZONE=$(jq -r '.TIMEZONE' config.json) # Timezone to use. Enter it as <continent>/<city>. For example: America/New_York
EXTERNAL_MONGODB_URI=$(jq -r '.EXTERNAL_MONGODB_URI' config.json) # External MongoDB Uri.
AGENDA_PATH=$(jq -r '.AGENDA_PATH' config.json) # The path to read the agenda jobs from. Defaults to /home/parse/jobs.js.

if [ "$EXTERNAL_MONGODB_URI" = "" ] ; then
  MONGODB_URI="mongodb://parse:$PARSE_DB_PASS@$DOMAIN:27017/$DATABASE_NAME?ssl=true"
else
  MONGODB_URI="$EXTERNAL_MONGODB_URI"
fi

# Prepare for background jobs using agenda.
cd /home/parse

# Install agenda.
npm install agenda

if [ "$AGENDA_PATH" = "" ] ; then
  AGENDA_PATH="/home/parse/jobs.js"

  # Create jobs.js file.
  echo "var Agenda = require('agenda');

  var agenda = new Agenda({db: {address: process.env.AGENDA_JOBS_DATABASE_URI}});

  // Asks Agenda to check for new tasks every minute.
  agenda.processEvery('1 minute');

  global.Parse = require('/usr/lib/node_modules/parse-server/node_modules/parse/node');
  Parse.initialize(process.env.AGENDA_JOBS_APPLICATION_ID, "", process.env.AGENDA_JOBS_MASTER_KEY);
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
  });" > $AGENDA_PATH
fi

# # Start agenda jobs with pm2.
sed -i "/}]/c\\
  },\n\
  {\n\
    \"name\"        : \"parse-jobs-wrapper\",\n\
    \"script\"      : \"$AGENDA_PATH\",\n\
    \"watch\"       : false,\n\
    \"merge_logs\"  : true,\n\
    \"cwd\"         : \"/home/parse\",\n\
    \"env\": {\n\
      \"AGENDA_JOBS_APPLICATION_ID\": \"$APPLICATION_ID\",\n\
      \"AGENDA_JOBS_MASTER_KEY\": \"$MASTER_KEY\",\n\
      \"AGENDA_JOBS_DATABASE_URI\": \"$MONGODB_URI\",\n\
    }\n\
  }]" /home/parse/ecosystem.json
