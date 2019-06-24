# k8s-service-account-config-generator
Bash script to generate a new service account in a specified name spaced and created the corresponding config file

```
~$ bash service_account_config_generator.sh -h
Service account config generation, usage: / -u|--user <SERVICE_ACCOUNT_NAME> [-n|--name-space <NAMESPACE>] [-f|--filename] <OUTPUT_FILE_NAME>

"-u|--user" requires an arument i.e "-u devuser1"
"-h|--help" help info, no arguments required
"-u|--user" Service account name
"-n|--name" Namespace (if not provided it will use default namesapce)
"-f|--filename" Output file name (if not provided will use <CLUSTERNAME>-context)
```
