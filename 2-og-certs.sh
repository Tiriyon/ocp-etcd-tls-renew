#!/bin/bash

ssh_user="core"
nodes_env_file="nodes.env"
etcd_secrets_dir="/etc/kubernetes/static-pod-resources/etcd-certs/secrets"
og_certs_tar="/tmp/og-certs-$(date +%Y%m%d).tar"
local_certs_tar="./og-certs-$(date +%Y%m%d).tar"
cluster_key="./cluster-key"
read -r master_hostname master_ip < "$nodes_env_file"
safe_send(){ f=$(mktemp -u); mkfifo $f; { (sleep ${1:-1}; echo >&3) } 3>$f & read -t ${1:-1} < $f; rm $f; }

ssh -i "./$cluster_key" -t "$ssh_user@$master_ip" "sudo bash -c '
tar cvf /tmp/og-certs-$(date +%Y%m%d).tar -C $etcd_secrets_dir .
'"; safe_send 8

scp -i "./$cluster_key" "$ssh_user@$master_ip:$og_certs_tar" "."; safe_send 8; echo "files at @oc_certs_tar"
tar xvf $local_certs_tar
