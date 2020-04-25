ROOT_PATH=/var/www/openode-api/
KUBE_CONFIGS_PATH=$ROOT_PATH"config/kubernetes/"
OUTPUT_BACKUP=/home/ubuntu/backup-kubes/
PREFIX_CONFIG_FILE=production-usa.yml

echo "--- "
echo "Configs:"
echo "KUBE_CONFIGS_PATH = $KUBE_CONFIGS_PATH"
echo "PREFIX_CONFIG_FILE = $PREFIX_CONFIG_FILE"
echo "OUTPUT_BACKUP = $OUTPUT_BACKUP"
echo "--- "

cd $KUBE_CONFIGS_PATH

cur_dir="$OUTPUT_BACKUP$PREFIX_CONFIG_FILE"

# create namespaces first
for ns_yml_file in $cur_dir/ns-instance-*
do
  echo "Current ns_yml_file $ns_yml_file"
  KUBECONFIG=$kube_config_file kubectl apply -f $ns_yml_file
done

for main_yml_file in $cur_dir/instance-*
do
  echo "Current main_yml_file $main_yml_file"
  KUBECONFIG=$kube_config_file kubectl apply -f $main_yml_file
done
