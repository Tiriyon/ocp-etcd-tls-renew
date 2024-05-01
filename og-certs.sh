#!/bin/bash

ssh_user="core"
nodes_env_file="nodes.env"
etcd_secrets_dir="/etc/kubernetes/static-pod-resources/etcd-certs/secrets"
og_certs_tar="/tmp/og-certs-$(date +%Y%m%d).tar"
read -r master_hostname master_ip < "$nodes_env_file"

ssh -i "./$cluster_key" -t "$ssh_user@$master_ip" "sudo bash -c '
tar cvf /tmp/og-certs-$(date +%Y%m%d).tar -C $etcd_secrets_dir . 
'"

scp -i "./$cluster_key" "$ssh_user@$master_ip:$og_certs_tar ." 
tar xvf $og_certs_tar
