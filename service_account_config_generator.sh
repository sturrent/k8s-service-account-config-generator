#!/bin/bash

##Beta V-0.3.5
## Creating service account and getting a corresponding kube config file for that
#"-u|--user" requires an arument i.e "-u devuser1"
#"-h|--help" help info, no arguments required
#"-n|--namespace" Namespace (if not provided it will use default namesapce)
#"-f|--filename" Output file name (if not provided will use <CLUSTERNAME>-context)'

# read the options
TEMP=`getopt -o u:n:f:h --long user:,namespace:,filename:,help -n 'service_account_config_generator.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
HELP=0
SA_NAME=""
NAMESPACE=""
CONFIG_FILE=""

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -u|--user) case "$2" in
            "") shift 2;;
            *) SA_NAME=$2; shift 2;;
            esac;;
        -n|--namespace) case "$2" in
            "") shift 2;;
            *) NAMESPACE=$2; shift 2;;
            esac;;
        -f|--filename) case "$2" in
            "") shift 2;;
            *) CONFIG_FILE=$2; shift 2;;
            esac;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

## vars and initialization
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')" 
if [ "$NAMESPACE" == "" ]; then
    NAMESPACE=default
    NAMESPACE_IS_DEFAULT=1
else
    NAMESPACE_IS_DEFAULT=0
fi

if [ "$CONFIG_FILE" == "" ]; then
    CONFIG_FILE="./${SA_NAME}_config"
fi

if [ -f $CONFIG_FILE ]; then
    echo -e "FYI, output file \"${CONFIG_FILE}\" already exists\n" 
fi

# check for package dependencies
if [ "$(which kubectl)" == "" ]; then
	echo -e "Error: Missing \"kubectl\" binary...\n"
	exit 4
fi

#if -h | --help option is selected or if anything other than -c or -v is selected, usage will be displayed
if [ $HELP -eq 1 ]
then
	echo "Service account config generation, usage: $SCRIPTPATH/$SCRIPT_NAME -u|--user <SERVICE_ACCOUNT_NAME> [-n|--namespace <NAMESPACE>] [-f|--filename] <OUTPUT_FILE_NAME>"
	echo -e '\n"-u|--user" requires an arument i.e "-u devuser1"
"-h|--help" help info, no arguments required
"-n|--namespace" Namespace (if not provided it will use default namesapce)
"-f|--filename" Output file name (if not provided will use <CLUSTERNAME>-context)'
	exit 0
fi

if [ -z $SA_NAME ]; then
	echo -e "Error: Service account name must be provided. \n"
	echo -e "Service account config generation, usage: $SCRIPTPATH/$SCRIPT_NAME -u|--user <SERVICE_ACCOUNT_NAME> [-n|--namespace <NAMESPACE>] [-f|--filename] <OUTPUT_FILE_NAME>\n"
	exit 5
fi

# create service account
if [ $NAMESPACE_IS_DEFAULT -eq 0 ]; then
    # checking if the namesapce already exists
    NAMESPACE_EXIST=$(kubectl get namespace $NAMESPACE 2> /dev/null)
    if [ "$NAMESPACE_EXIST" == "" ]; then
        echo -e "\nCreating namespace..."
        kubectl create namespace $NAMESPACE
    fi
fi

echo -e "\nCreating service account..."
kubectl create sa $SA_NAME -n $NAMESPACE

# get secrete for service account
SA_SECRETE=$(kubectl -n $NAMESPACE get sa $SA_NAME -o yaml | grep token | awk '{print $NF}')

# get ca cert
kubectl -n $NAMESPACE get secret $SA_SECRETE -o yaml | grep 'ca.crt:' | awk '{print $2}' | base64 -d > /tmp/temp_ca_server.crt

# get sa token
SA_TOKEN=$(kubectl -n $NAMESPACE get secret $SA_SECRETE -o yaml | grep 'token:' | awk '{print $2}' | base64 -d)

## get info from cluster and context

# get current context
CONTEXT_NAME=$(kubectl config current-context)

# get cluster name of context
CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT_NAME | awk '{print $3}' | tail -n 1)

# get endpoint of current context 
ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$CLUSTER_NAME\")].cluster.server}")

# config cluster
echo -e "\nSetting kube config file for user ${SA_NAME}..."
kubectl --kubeconfig=$CONFIG_FILE config set-cluster $CLUSTER_NAME \
  --embed-certs=true \
  --server=$ENDPOINT \
  --certificate-authority=/tmp/temp_ca_server.crt
  
# config sa with token
kubectl --kubeconfig=$CONFIG_FILE config set-credentials $SA_NAME --token=$SA_TOKEN

# set context
kubectl --kubeconfig=$CONFIG_FILE config set-context ${SA_NAME}-on-${CLUSTER_NAME}-context \
  --cluster=$CLUSTER_NAME \
  --user=$SA_NAME \
  --namespace=$NAMESPACE
kubectl --kubeconfig=$CONFIG_FILE config use-context ${SA_NAME}-on-${CLUSTER_NAME}-context
###
echo -e "\nExecution completed successfully, config file for user $SA_NAME and context ${SA_NAME}-on-${CLUSTER_NAME}-context is in $CONFIG_FILE
You can run commands with user $SA_NAME using the --kubeconfig option from kubectl
EX:
kubectl --kubeconfig=${CONFIG_FILE} get po \n"

## cleanup 
rm -f /tmp/temp_ca_server.crt 2> /dev/null

exit 0