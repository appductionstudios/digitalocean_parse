# Install Parse Server and Dashboard on DigitalOcean #

1. Create an Ubuntu 14.04 machine on [DigitalOcean](www.digitalocean.com) with enabled IPv6 and add an SSH key.

2. Setup a hostname for your DigitalOcean machine. Tutorials can be found [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-host-name-with-digitalocean) and [here](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars).

3. Pull this repo into your machine.

4. On your machine set all variables in **./config.json** then run `sh ./run_parse.sh`.

5. Copy the generated **mongodb://** url and use it for your migration on Parse.com.

6. For background jobs run `sh add_jobs.sh`. Then copy your background jobs to /root/parse-server-example/jobs.js file. And run `pm2 restart parse-server-wrapper`. Make sure to copy each job separately to ensure following the agenda syntax.

7. To sync the cloud code with your repo run `sh parse_deploy.sh`. Make sure you have the cloud params set in your config.json before running this.

Note: This script is based on these tutorials:

* [Install Parse Server Example](https://www.digitalocean.com/community/tutorials/how-to-run-parse-server-on-ubuntu-14-04)

* [Migrate A Parse App To Parse Server](https://www.digitalocean.com/community/tutorials/how-to-migrate-a-parse-app-to-parse-server-on-ubuntu-14-04)

## Backgrounds jobs.

The script uses [Agenda](https://github.com/rschmukler/agenda) for backgrounds jobs. After running the script open **/root/parse-server-example/jobs.js** and add your jobs. Refer to the example task under the created jobs.js file and Agenda's [github](https://github.com/rschmukler/agenda) for more information on how to use and configure background jobs.

## Variable description.

**DOMAIN**

The domain to use for your parse-server, parse-dashboard as well as mongo database.
For example, parse.mydomain.com sets up your environment as follows:

mongodb: parse.mydomain.com:27017

parse-server: parse.mydomain.com/parse (internally forwards to localhost:1337)

parse-dashboard: parse.mydomain.com:4040/dashboard

**PARSE_DB_PASS**

The password to use with the "parse" mongo db user.

**SWAPSIZE**

The swap size to use with your Ubuntu machine. For example 1G.

**USERNAME and PASSWORD**

Credentials for your Ubuntu user.

**PARSE_USER_PASSWORD**

The script creates a dedicated "parse" user on your Ubuntu machine. Set the password to use with this user.

**EMAIL_ADDRESS**

The email address to associate with the [letsencrypt](https://letsencrypt.org/) subscription.

**DATABASE_NAME**

The name of the mongo database to create for your parse app.

**MONGO_USER and MONGO_PASS**

Credentials for your mongo admin user.

**APP_NAME**

What to name your app on the parse-dashboard.

**APPLICATION_ID and MASTER_KEY**

Application ID and Master Key to use on your parse-dashboard as well as parse-server.

**DASHBOARD_USERNAME and DASHBOARD_PASSWORD**

Credentials of your dashboard user.

**TIMEZONE**

Timezone to use. Enter it as Continent/City. For example: America/New_York

**CLOUD_REPO_TYPE** (optional)

Defines the type of repo. Can be set to either "hg" or "git".

**CLOUD_REPO_LINK** (optional)

Command/URL to run after git clone or hg clone. This is usually the url to your repo. If additional params are needed for cloning, for example https://my-repo-url -b branch add them to this command.

**CLOUD_PATH** (optional)

Path of cloud folder within repository. If files are already on repo root level enter ".".

**PRE_CLOUD_SCRIPT** (optional)

Path to a shell script you create within your cloud code repository, that installs any additional dependencies your cloud code needs to run.

**VERIFY_EMAIL** (optional)

When set to true send verification emails to new users. When set EMAIL_ADAPTER_MODULE, EMAIL_FROM_ADDRESS, EMAIL_DOMAIN and EMAIL_API_KEY need to be set.

**PREVENT_UNVERIFIED_EMAIL_LOGIN** (optional)

When set to true prevents users with unverified emails to login.

**EMAIL_ADAPTER_MODULE** 

The email adapter to use. Currently parse supports:

[parse-server-simple-mailgun-adapter](https://github.com/ParsePlatform/parse-server-simple-mailgun-adapter) - default

[parse-server-mailgun](https://github.com/sebsylvester/parse-server-mailgun)

[parse-server-postmark-adapter](https://www.npmjs.com/package/parse-server-postmark-adapter)

[parse-server-sendgrid-adapter](https://www.npmjs.com/package/parse-server-sendgrid-adapter)

[parse-server-mandrill-adapter](https://www.npmjs.com/package/parse-server-mandrill-adapter)

[parse-server-simple-ses-adapter](https://www.npmjs.com/package/parse-server-simple-ses-adapter)

In case of using an adapter other than mailgun, make sure to npm install the respective models.

**EMAIL_FROM_ADDRESS**

The email address to use with email verification and password reset emails.

**EMAIL_DOMAIN**

The domain provided by your email provider.

**EMAIL_API_KEY**

The API key provided by your email provider.

## Mailgun Params ##

The *MAILGUN_* params only work when *parse-server-mailgun* is chosen as the email adapter.

**MAILGUN_PASSWORD_RESET_SUBJECT**

Subject of password reset email.

**MAILGUN_PASSWORD_RESET_PLAIN_TXT_PATH**

Path to password reset txt template.

**MAILGUN_PASSWORD_RESET_HTML_PATH**

Path to password reset html template.

**MAILGUN_EMAIL_CONFIRMATION_SUBJECT**

Subject of email confirmation email.

**MAILGUN_EMAIL_CONFIRMATION_PLAIN_TXT_PATH**

Path to email confirmation txt template.

**MAILGUN_EMAIL_CONFIRMATION_HTML_PATH**

Path to email confirmation txt template.

**FILE_ADAPTER_MODULE**

The file adapter module to use. Currently only parse-server-s3-adapter is supported. Leave empty to use MongoDB's GridFS.

The *S3_* params only work when *parse-server-S3_adapter* is chosen as the file adapter.

**S3_ACCESS_KEY**

Access Key to your S3 Bucket.

**S3_SECRET_KEY**

Secret Key to your S3 Bucket.

**S3_BUCKET_NAME**

**Name of your S3 Bucket.**

**S3_REGION**

The region of your S3 Bucket. Defaults to us-east-1.
