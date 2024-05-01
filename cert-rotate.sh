#!/bin/bash

cluster_key="cluster-key"

# Define local directories
local_peer_dir="./new-certs/peer"
local_serving_dir="./new-certs/serving"
local_serving_metrics_dir="./new-certs/serving-metrics"

# Define remote directories
remote_peer_dir="/etc/kubernetes/static-pod-resources/etcd-certs/secrets/etcd-all-peer"
remote_serving_dir="/etc/kubernetes/static-pod-resources/etcd-certs/secrets/etcd-all-serving"
remote_serving_metrics_dir="/etc/kubernetes/static-pod-resources/etcd-certs/secrets/etcd-all-serving-metrics"

# Backup date
backup_date=$(date +%Y%m%d)

# Function to stop control plane components
stop_control_plane() {
    local ip_address=$1
    echo "Stopping control plane components on $ip_address..."
    ssh -i "$cluster_key" core@$ip_address "sudo crictl stop \$(sudo crictl ps | grep -e 'etcd\|kube-apiserver\|kube-controller\|kube-scheduler' | awk '{print \$1}')"
}

# Function to check control plane status
check_control_plane() {
    local ip_address=$1
    echo "Checking control plane status on $ip_address..."
    if ssh -i "$cluster_key "core@$ip_address "sudo crictl ps | grep -e 'etcd\|kube-apiserver\|kube-controller\|kube-scheduler'" >/dev/null; then
        echo "Control plane components are still running on $ip_address. Aborting operation."
        exit 1
    else
        echo "Control plane components are stopped on $ip_address."
    fi
}

# Function to check backup status
check_backup_status() {
    local ip_address=$1
    echo "Checking backup status on $ip_address..."
    if ssh -i "$cluster_key "core@$ip_address "[ -d /etc/kubernetes/static-pod-resources/etcd-certs-backup-$backup_date ]"; then
        echo "Backup exists on $ip_address."
    else
        echo "Backup does not exist on $ip_address. Aborting operation."
        exit 1
    fi
}

# Function to copy certificates to a remote node
copy_certs() {
    local ip_address=$1
    local source_dir=$2
    local target_dir=$3
    local cert_type=$4

    echo "Copying $cert_type certificates to $hostname ($ip_address)..."
    scp -i "$cluster_key" -r "$source_dir/"* "core@$ip_address:$target_dir/"
}

# Read each line from nodes.env and process each node
while IFS=' ' read -r hostname ip_address; do
    echo "Processing node $hostname with IP $ip_address..."

    # Stop control plane and check
    stop_control_plane "$ip_address"
    check_control_plane "$ip_address"
    check_backup_status "$ip_address"

    # Copy certificates for peer, serving, and serving-metrics
    copy_certs "$ip_address" "$local_peer_dir" "$remote_peer_dir" "peer"
    copy_certs "$ip_address" "$local_serving_dir" "$remote_serving_dir" "serving"
    copy_certs "$ip_address" "$local_serving_metrics_dir" "$remote_serving_metrics_dir" "serving-metrics"
done < nodes.env

echo "Certificate rotation completed successfully for all nodes."
