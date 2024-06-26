#!/bin/bash

# Function to fetch etcd certificate objects
get_etcd_cert_objects() {
    oc get secret -n openshift-etcd -o jsonpath='{range .items[?(.type=="kubernetes.io/tls")]}{.metadata.name}{"\n"}{end}' | grep -e "etcd-peer\|etcd-serving"
}

# Function to verify and print dates of certificates
verify_and_print_dates() {
    local cert_objects="$1"
    for cert_name in $cert_objects; do
        oc get secret "$cert_name" -n openshift-etcd -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -noout -dates && echo '-----'
    done
}

# Function to backup etcd certificates
backup_etcd_certs() {
    local cert_objects="$1"
    oc get secret -o yaml -n openshift-etcd $cert_objects > manifest-etcd-certs-backup.yaml
}

# Main method
main() {
    local cert_objects="$(get_etcd_cert_objects)"
    verify_and_print_dates "$cert_objects"
    backup_etcd_certs "$cert_objects"
}

# Execute main method
main

