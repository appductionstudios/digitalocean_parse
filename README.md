# Install Parse Server and Dashboard on DigitalOcean #

1. Create an Ubuntu 14.04 machine on [DigitalOcean](www.digitalocean.com) with enabled IPv6 and add an SSH key.

2. Setup a hostname for your DigitalOcean machine. Tutorials can be found [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-host-name-with-digitalocean) and [here](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars).

3. Pull this repo into your machine under /root.

4. On your machine set all variables in **/root/migrate_parse.sh** then run the script.

5. Copy the generated **mongodb://** url and use it for your migration on Parse.com.

Note: This script is based on these tutorials:

* [Install Parse Server Example](https://www.digitalocean.com/community/tutorials/how-to-run-parse-server-on-ubuntu-14-04)

* [Migrate A Parse App To Parse Server](https://www.digitalocean.com/community/tutorials/how-to-migrate-a-parse-app-to-parse-server-on-ubuntu-14-04)

## Variable description.

**DOMAIN**

The domain to use for your parse-server, parse-dashboard as well as mongo database.
For example, parse.mydomain.com means sets up your environment as follows:

mongodb: parse.mydomain.com:27017

parse-server: parse.mydomain.com/parse (internally forwards to localhost:1337)

parse-dashboard: parse.mydomain.com:4040

**PARSE_DB_PASS**

The password to use with the "parse" mongo db user.

**SWAPSIZE**

The swap size to use with your Ubuntu machine. For example 1G.

**USERNAME and PASSWORD**

Credentials for your Ubuntu user.

**PARSE_USER_PASSWORD**

The script creates a dedicated "parse" user on your Ubuntu machine. Set the password to use with this user.

**EMAIL_ADDRESS**

The email address to associate with the letsencrypt subscription.

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

Timezone to use. Enter it as <continent>/<city>. For example: America/New_York

**CLOUD_REPO_TYPE** (optional)

Defines the type of repo. Can be set to either "hg" or "git".

**CLOUD_REPO_LINK** (optional)

Command/URL to run after git clone or hg clone. This is usually the url to your repo. If additional params are needed for cloning, for example https://<my-repo-url> -b <branch add them to this command.

**CLOUD_PATH** (optional)

Path of cloud folder within repository. If files are already on repo root level enter ".".

**PRE_CLOUD_SCRIPT** (optional)

In some cases additional requirements or dependencies are needed for your cloud code to run. In that case add this as a .sh file in your cloud repo and point this variable to the path of the script within the cloud folder.

