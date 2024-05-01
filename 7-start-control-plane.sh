#!/bin/bash

cluster_key="cluster-key"
backup_date=$(date +%Y%m%d)

# Function to restore Kubernetes manifests
restore_manifests() {
    local ip_address=$1
    echo "Restoring Kubernetes manifests on $ip_address..."

    # Move manifests from backup to original directory
    ssh -i "$cluster_key" core@$ip_address "sudo mv /etc/kubernetes/manifests-backup-$backup_date/* /etc/kubernetes/manifests/"

    # Verify restoration
    if ssh -i "$cluster_key" core@$ip_address "ls /etc/kubernetes/manifests/"; then
        echo "Manifests restored successfully on $ip_address."
    else
        echo "Failed to restore manifests on $ip_address."
        exit 1
    fi
}

# Function to check if the control plane is up
check_control_plane() {
    local ip_address=$1
    echo "Checking control plane status on $ip_address..."
    local start_time=$(date +%s)
    local timeout=600 # 10 minutes in seconds

    # Loop until all control plane components are running or timeout
    while true; do
        if ssh -i "$cluster_key" core@$ip_address "sudo crictl ps | grep -e 'etcd\|kube-apiserver\|kube-controller\|kube-scheduler'" > /dev/null; then
            echo "Control plane is up and running on $ip_address."
            break
        else
            echo "Waiting for control plane to start on $ip_address..."
            sleep 30
        fi

        local current_time=$(date +%s)
        if (( current_time - start_time > timeout )); then
            echo "Timeout: Control plane did not start within the expected time on $ip_address."
            exit 1
        fi
    done
}

# Read each line from nodes.env and process each node
exec 3< nodes.env
while IFS=' ' read -r hostname ip_address <&3; do
    echo "Processing node $hostname with IP $ip_address..."
    restore_manifests "$ip_address"
    check_control_plane "$ip_address"
done

echo "Control plane start-up process completed for all specified nodes."
