CLOUD_REPO_TYPE=$(jq -r '.CLOUD_REPO_TYPE' config.json) # Set to either "hg" or "git".
CLOUD_REPO_LINK=$(jq -r '.CLOUD_REPO_LINK' config.json) # Command/URL to run after git clone or hg clone.
CLOUD_PATH=$(jq -r '.CLOUD_PATH' config.json) # Path of cloud folder within repository. If files are already on repo root level enter ".".
PRE_CLOUD_SCRIPT=$(jq -r '.PRE_CLOUD_SCRIPT' config.json) # Path to a shell script, that may install any missing requirements before installing your cloud code.

rm -r /root/cloud_dir

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

pm2 restart parse-server-wrapper
