source config.sh
source utils.sh

go get github.com/onsi/ginkgo/ginkgo
announce "UNIT TESTS"
home_dir=$(pwd)
cd concourse/atc/creds/conjur
output=$($HOME/go/bin/ginkgo -r -p)
cd "$home_dir"
echo "$output"

if [[ "$output" != *"Test Suite Passed"* ]]; then
	echo "ERROR: Failed to pass unit tests"
	exit 1
fi

announce "INTEGRATION TESTS"
header=$(conjur_authenticate)

announce "#--> Fetch from non-existent variables"
delete_variable team
delete_variable pipeline
delete_variable vault
fly -t test trigger-job -j test-pipeline/job-conjur-api-key
fly -t test watch -j test-pipeline/job-conjur-api-key
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
if [[ "$output" != *"undefined vars: api_key"* ]]; then 
  echo "ERROR: Found api_key and it should not have been found"
  exit 1
fi


announce "#---> Fetch from team variable"
append_policy root policy.yml
set_variable "concourse/testTeam/api_key" "$API_KEY_TEAM"
delete_variable pipeline
delete_variable vault
fly -t test trigger-job -j test-pipeline/job-conjur-api-key
fly -t test watch -j test-pipeline/job-conjur-api-key
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
fetched_api_key=$(echo "$output" | grep "API_KEY=$API_KEY_TEAM")
if [[ "$fetched_api_key" == "" ]]; then
  echo "ERROR: Failed to find api_key for team"
  exit 1
fi


announce "#---> Fetch from pipeline variable"
append_policy root policy.yml
set_variable "concourse/testTeam/test-pipeline/api_key" "$API_KEY_PIPELINE"
delete_variable vault
fly -t test trigger-job -j test-pipeline/job-conjur-api-key
fly -t test watch -j test-pipeline/job-conjur-api-key
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
fetched_api_key=$(echo "$output" | grep "API_KEY=$API_KEY_PIPELINE")
if [[ "$fetched_api_key" == "" ]]; then
  echo "ERROR: Failed to find api_key for pipeline"
  exit 1
fi


announce "#---> Fetch from vault variable"
append_policy root policy.yml
set_variable "vaultName/api_key" "$API_KEY_VAULT"
delete_variable team
delete_variable pipeline
fly -t test trigger-job -j test-pipeline/job-conjur-api-key
fly -t test watch -j test-pipeline/job-conjur-api-key
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
fetched_api_key=$(echo "$output" | grep "API_KEY=$API_KEY_VAULT")
if [[ "$fetched_api_key" == "" ]]; then
  echo "ERROR: Failed to find api_key for vault"
  exit 1
fi

announce "#---> Fetch while conjur is down"
docker-compose stop
fly -t test trigger-job -j test-pipeline/job-conjur-api-key
fly -t test watch -j test-pipeline/job-conjur-api-key
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
output=$(fly -t test watch -j test-pipeline/job-conjur-api-key)
docker-compose up -d
if [[ "$output" != *"undefined vars: api_key"* ]]; then 
  echo "ERROR: Found api_key and it should not have been found"
  exit 1
fi




