# k8s-service-account-config-generator
Bash script to generate a new service account in a specified namespace and create the corresponding config file.
The script will create a service account and generate the corresponding kube config file to authenticate with that account.
If no namespace is specified the script will use the default one, and if a different namespace is provided the script will create it if is not already in place.

# Getting the script
You can download the `service_account_generator.sh` file or clone this git repo.
Then provide execution privileges and you are ready to go.

EX:
```
~$ git clone https://github.com/sturrent/k8s-service-account-config-generator.git
~$ cd k8s-service-account-config-generator
~$ chmod u+x service-account-config-generator.sh
~$ ./service-account-config-generator.sh --help
```


# Usage
```
~$ bash service_account_config_generator.sh -h
Service account config generation, usage: / -u|--user <SERVICE_ACCOUNT_NAME> [-n|--namespace <NAMESPACE>] [-f|--filename] <OUTPUT_FILE_NAME>

"-u|--user" requires an arument i.e "-u devuser1"
"-h|--help" help info, no arguments required
"-n|--namespace" Namespace (if not provided it will use default namesapce)
"-f|--filename" Output file name (if not provided will use <CLUSTERNAME>-context)
```
# Simpla way to merge kube config files
```
KUBECONFIG=~/.kube/config:<EXTRA_CONFIG_FILE> kubectl config view --flatten > <NEW_CONF_WITH_BOTH_FILES>

EX:
~$ KUBECONFIG=~/.kube/config:devuser1-on-akscluster1 kubectl config view --flatten > new_cube_conf
```

# Roles and Rolebindings
Once you have a new service account, by default it will not have any privileges.
You will have to use roles and rolebindings to grant privileges for that account.
And the cluster must have RBAC enabled, if not the service accounts will not have any restrictions.

Here is a pod reader sample creating a new role `pod-reader` for service account `dev1user` and the corresponding rolebinding:

```
# Role
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF
```

```
# Rolebinding
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-dev1user
subjects:
- kind: ServiceAccount
  name: dev1user
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

After those are in place the `dev1user` can use read-only commands with pods over the default namespace.
