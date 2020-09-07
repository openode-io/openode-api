ROOT_PATH=/var/www/openode-api/
KUBE_CONFIGS_PATH=$ROOT_PATH"config/kubernetes/"
PREFIX_CONFIG_FILES=production-
OUTPUT_BACKUP=/home/ubuntu/backup-kubes/
PATH=$PATH:/bin:/usr/bin

echo "--- "
echo "Configs:"
echo "KUBE_CONFIGS_PATH = $KUBE_CONFIGS_PATH"
echo "PREFIX_CONFIG_FILES = $PREFIX_CONFIG_FILES"
echo "OUTPUT_BACKUP = $OUTPUT_BACKUP"
echo "--- "

cd $KUBE_CONFIGS_PATH
mkdir -p $OUTPUT_BACKUP

for kube_config_file in $PREFIX_CONFIG_FILES*
do
  cur_dir="$OUTPUT_BACKUP$kube_config_file"
  mkdir -p $cur_dir

  nss=`KUBECONFIG=$kube_config_file kubectl get namespaces | awk '{print $1}' | grep "^instance-"`

  for namespace in $nss
  do
    ns_yml_file="$cur_dir/ns-$namespace.yml"
    ns_main_yml_file="$cur_dir/$namespace.yml"

    echo "Backuping namespace $namespace in $ns_yml_file"
    KUBECONFIG=$kube_config_file kubectl -n $namespace get namespace $namespace -o yaml > $ns_yml_file
    
    echo "---" > $ns_main_yml_file

    for resource in "services" "deployments" "configmaps" "pvc" "secrets" "ingresses"
    do
      echo "Backuping $namespace $resource"

      KUBECONFIG=$kube_config_file kubectl -n $namespace get $resource -o yaml >> $ns_main_yml_file
      echo "---" >> $ns_main_yml_file
      sleep 0.5
    done
  done
done
