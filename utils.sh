function conjur_authenticate {
	api_key=$(curl -s -k --user "admin:$ADMIN_PASSWORD" https://conjur-master/authn/conjur/login)
	session_token=$(curl -s -k --data "$api_key" https://conjur-master/authn/conjur/admin/authenticate)
	token=$(echo -n $session_token | base64 | tr -d '\r\n')
	header="Authorization: Token token=\"$token\""
	echo "$header"
}

function delete_variable {
	variable_name=$1
	echo "deleting variable: $variable_name"
	output=$(curl -H "$header" -X PATCH -d "$(< policies/delete-$variable_name-variable.yml)" -s -k https://conjur-master/policies/conjur/policy/root)
}

function append_policy {
	policy_branch=$1
	policy_name=$2
	response=$(curl -H "$header" -X POST -d "$(< policies/$policy_name)" -s -k https://conjur-master/policies/conjur/policy/$policy_branch)
	echo "$response"
}

function set_variable {
	variable_name=$1
	variable_value=$2
	curl -k -s -H "$header" --data "$variable_value" https://conjur-master/secrets/conjur/variable/$variable_name
}

function announce {
	echo "##############################################"
	echo "$1"
	echo "##############################################"
}