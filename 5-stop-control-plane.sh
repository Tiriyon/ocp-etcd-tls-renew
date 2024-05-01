#!/bin/bash

cluster_key="cluster-key"
backup_date=$(date +%Y%m%d)

# Function to stop and verify control plane components
stop_and_verify_control_plane() {
    local ip_address=$1
    echo "Attempting to stop control plane components on $ip_address..."

    # Attempt to stop control plane components, ignoring errors
    local stop_attempts=3
    for attempt in $(seq 1 $stop_attempts); do
        ssh -i "$cluster_key" core@$ip_address "sudo crictl ps | grep -e 'etcd\|kube-apiserver\|kube-controller\|kube-scheduler' | awk '{print \$1}' | xargs -r sudo crictl stop"
        sleep 5

        # Verify that no control plane components are running
        if ssh -i "$cluster_key" core@$ip_address "sudo crictl ps | grep -e 'etcd\|kube-apiserver\|kube-controller\|kube-scheduler'"; then
            echo "Attempt $attempt: Control plane components are still running on $ip_address."
            if [ $attempt -eq $stop_attempts ]; then
                echo "Failed to stop control plane components after $stop_attempts attempts on $ip_address."
                return 1  # Return a failure status
            fi
        else
            echo "Control plane components are successfully stopped on $ip_address."
            return   # Success
        fi
    done
}

# Function to backup and verify Kubernetes manifests
backup_and_verify_manifests() {
    local ip_address=$1
    echo "Backing up Kubernetes manifests on $ip_address..."

    # Create backup directory and copy manifests
    ssh -i "$cluster_key" core@$ip_address "sudo mkdir -p /etc/kubernetes/manifests-backup-$backup_date && sudo cp /etc/kubernetes/manifests/* /etc/kubernetes/manifests-backup-$backup_date/"

    # Verify backup by comparing checksums
    local original_checksums=$(ssh -i "$cluster_key" core@$ip_address "sudo sha256sum /etc/kubernetes/manifests/* | awk '{print \$1}'")
    local backup_checksums=$(ssh -i "$cluster_key" core@$ip_address "sudo sha256sum /etc/kubernetes/manifests-backup-$backup_date/* | awk '{print \$1}'")

    if [[ "$original_checksums" == "$backup_checksums" ]]; then
        echo "Manifests backup verified successfully on $ip_address."
        # Remove original manifests if checksums match
        ssh -i "$cluster_key" core@$ip_address "sudo rm /etc/kubernetes/manifests/*"
    else
        echo "Checksum mismatch. Backup verification failed on $ip_address."
        return 1
    fi
}

# Ensure nodes.env file exists
if [[ ! -f nodes.env ]]; then
    echo "Error: nodes.env file does not exist."
    exit 1
fi

# Read each line from nodes.env and process each node

exec 3< nodes.env
while IFS=' ' read -r hostname ip_address <&3; do
    echo "DEBUG: Processing node $hostname with IP $ip_address..."
    backup_and_verify_manifests "$ip_address"
    stop_and_verify_control_plane "$ip_address"
done

echo "Control plane stoppage and verification completed for all specified nodes."
