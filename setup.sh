source config.sh
source utils.sh

if [[ "$1" != "" ]]; then
  IP_INTERFACE=$1
fi

echo "getting ip address"
ip_address=""
if [[ "$2" == "mac" ]]; then
  ip_address=$(ifconfig "$IP_INTERFACE" | grep inet | tail -n 1 | awk '{print $2}')
elif [[ "$2" == "ubuntu" ]]; then
  ip_address=$(ifconfig "$IP_INTERFACE" | grep inet | head -n 1 | awk -F ":" '{print $2}' | awk '{print $1}')
else
  echo "ERROR: Invalid system type. supported types are mac and ubuntu"
  exit 1
fi

if [[ "$ip_address" == "" ]]; then
  echo "ERROR: Failed to get ip address"
  exit 1
fi


echo "download & install conjur"
docker-compose up -d
docker exec $CONJUR_NAME evoke configure master --accept-eula --hostname $CONJUR_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT_NAME
sleep 5

echo "get conjur certificate"
openssl s_client -showcerts -connect $CONJUR_NAME:443 < /dev/null 2> /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > conjur-conjur.pem

echo "configure conjur with default policies and secret values"
header=$(conjur_authenticate)
api_key=$(append_policy root policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')

if [ "$api_key" == "{}" ]; then
  echo "ERROR: Could not get api_key for generated host"
  exit 1
fi

echo "download & run concourse"
git clone --single-branch --branch conjur-credential-manager https://github.com/cyberark-bizdev/concourse
sed "s/{{ API_KEY }}/$api_key/g" docker-compose-concourse.yml | sed "s/{{ HOST_IP }}/$ip_address/g" > concourse/docker-compose.yml

cd concourse
# TODO: install yarn
yarn install
yarn build
docker-compose up --build -d
sleep 20
cd ..


echo "configure concourse"

type="linux"
if [[ "$2" == "mac" ]]; then
  type="darwin"
fi

wget "http://localhost:8080/api/v1/cli?arch=amd64&platform=$type" -O fly
chmod +x ./fly
./fly --target test login --concourse-url http://127.0.0.1:8080 -u test -p test
./fly -t test set-team --team-name testTeam --local-user test --non-interactive
./fly -t test login --concourse-url http://127.0.0.1:8080 -n testTeam -u test -p test
./fly -t test set-pipeline -p test-pipeline -c $(pwd)/pipelines/pipeline.yml -n
./fly -t test unpause-pipeline -p test-pipeline
