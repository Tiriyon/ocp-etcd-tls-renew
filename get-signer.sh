#!/bin/bash

ssh_user="core"
# Singers to extract
signers=("etcd-signer" "etcd-metric-signer")
nodes_env_file="nodes.env"
read -r master_hostname master_ip < "$nodes_env_file"
echo "Extracting root certificates from: $master_hostname - $master_ip"

# Root certificate dirs
remote_root_certs_dir="/etc/kubernetes/etcd-singers-$(date +%Y%m%d)"
local_root_certs_dir="./etcd-signers-$(date +%Y%m%d)"
mkdir -p "$local_root_certs_dir"

# Prepare directory on remote (first master node on nodes.env)
ssh -i ./cluster-key -t "$ssh_user@$master_ip" "sudo bash -c 'mkdir -p $remote_root_certs_dir && rm -rf $remote_root_certs_dir/*'"

# Extract certificates and keys remotely and copy them locally
for signer in "${signers[@]}"; do
  echo "Processing $signer..."
  ssh -i ./cluster-key -t "$ssh_user@$master_ip" "sudo bash -c '
  grep -A55 -a \"openshift-config/$signer\" /var/lib/etcd/member/snap/db | sed -n \"/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p\" > \"$remote_root_certs_dir/$signer.crt\"
  grep -A55 -a \"openshift-config/$signer\" /var/lib/etcd/member/snap/db | sed -n \"/-----BEGIN RSA PRIVATE KEY-----/,/-----END RSA PRIVATE KEY-----/p\" > \"$remote_root_certs_dir/$signer.key\"
  '"
  # COPY to local
  scp -i ./cluster-key "$ssh_user@$master_ip:$remote_root_certs_dir/$signer.crt" "$local_root_certs_dir/$signer.crt"
  scp -i ./cluster-key "$ssh_user@$master_ip:$remote_root_certs_dir/$signer.key" "$local_root_certs_dir/$signer.key"
done

echo "Extraction and transfer process completed. Check $local_root_certs_dir for certificates and keys with validation script"
