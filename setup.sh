export IMAGE_NAME="captainfluffytoes/dap:11.1"
export CONJUR_NAME="conjur-master"
export ADMIN_PASSWORD="Cyberark1"
export CONJUR_ACCOUNT_NAME="conjur"
export HOST_USERNAME="host/jenkins-test"
export CONJUR_PLUGIN_PATH="/Users/acopeland/Downloads/Conjur.hpi"


echo "download & install jenkins"
docker pull jenkins/jenkins
docker run -d --env JAVA_OPTS=-Djenkins.install.runSetupWizard=false -p 8080:8080 --name=jenkins-master jenkins/jenkins

echo "download & install conjur"
docker pull $IMAGE_NAME
docker container run -d --name $CONJUR_NAME --restart=always --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $IMAGE_NAME
docker exec $CONJUR_NAME evoke configure master --accept-eula --hostname $CONJUR_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT_NAME



echo "configure conjur with default policies and secret values"
pip3 install conjur-client
api_key=$(conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         policy apply root policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')

if [ "$api_key" == "{}" ]; then
  echo "ERROR: Could not get api_key for generated host"
  return 1
fi

# populate the secret values
conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         variable set git/access-token $GIT_ACCESS_TOKEN


conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         variable set git/ssh-key $GIT_SSH_KEY


echo "import the conjur credential plugin: $CONJUR_PLUGIN_PATH"
curl -i -F file=@$CONJUR_PLUGIN_PATH http://localhost:8080/pluginManager/uploadPlugin
sleep 15

echo "restarting jenkins"
curl http://localhost:8080/safeRestart/safeRestart --data {}

         
echo "======= ENVIRONMENT VARIABLE ======="
echo "export APPLIANCE_URL=https://$CONJUR_NAME"
echo "export CONJUR_AUTHN_LOGIN=$HOST_USERNAME"
echo "export CONJUR_API_KEY=$api_key"
echo "export CONJUR_ACCOUNT=$CONJUR_ACCOUNT_NAME"
