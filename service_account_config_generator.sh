#!/bin/bash

## Creating service account and getting a corresponding kube config file for that

## Verifications before the run
# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; then
    echo -e "Usage: $0 <SERVICE_ACCOUNT_NAME>\n"
    exit 1
fi
# check for package dependencies
if [ "$(which jq)" == "" ]; then
	echo -e "Error: Missing \"jq\" binary, you can install it with: sudo apt install jq\n"
	exit 1
fi

## vars
SA_NAME=$1
NAMESPACE=default
CONFIG_FILE="./${SA_NAME}_config"

# create service account
kubectl create sa $SA_NAME -n $NAMESPACE

# get secrete for service account
SA_SECRETE=$(kubectl -n $NAMESPACE get sa $SA_NAME -o json | jq -r .secrets[].name)

# get ca cert
kubectl -n $NAMESPACE get secret $SA_SECRETE -o json | jq -r '.data["ca.crt"]' | base64 -d > /tmp/temp_ca_server.crt

# get sa token
SA_TOKEN=$(kubectl -n $NAMESPACE get secret $SA_SECRETE -o json | jq -r '.data["token"]' | base64 -d)

## get info from cluster and context

# get current context
CONTEXT_NAME=$(kubectl config current-context)

# get cluster name of context
CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT_NAME | awk '{print $3}' | tail -n 1)

# get endpoint of current context 
ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$CLUSTER_NAME\")].cluster.server}")

# create empty conf file
touch $CONFIG_FILE


# config cluster
kubectl --kubeconfig=$CONFIG_FILE config set-cluster $CLUSTER_NAME \
  --embed-certs=true \
  --server=$ENDPOINT \
  --certificate-authority=/tmp/temp_ca_server.crt
  
# config sa with token
kubectl --kubeconfig=$CONFIG_FILE config set-credentials $SA_NAME --token=$SA_TOKEN

# set context
kubectl --kubeconfig=$CONFIG_FILE config set-context ${CLUSTER_NAME}-context \
  --cluster=$CLUSTER_NAME \
  --user=$SA_NAME \
  --namespace=$NAMESPACE

###
echo -e "\nExecution completed successfully, config file for user $SA_NAME and context $CONTEXT_NAME is in $CONFIG_FILE \n"
echo -e "You can run command with user $SA_NAME using the --kubeconfig option from kubectl\n
EX:\n
kubectl --kubeconfig=${CONFIG_FILE} config use-context ${CLUSTER_NAME}-context
kubectl --kubeconfig=${CONFIG_FILE} get po \n"

## cleanup 
rm -f /tmp/temp_ca_server.crt 2> /dev/null