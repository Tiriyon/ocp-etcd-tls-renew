#!/bin/bash

# Function to fetch etcd certificate objects
get_etcd_cert_objects() {
    oc get secret -n openshift-etcd -o jsonpath='{range .items[?(.type=="kubernetes.io/tls")]}{.metadata.name}{"\n"}{end}' | grep -e "etcd-peer\|etcd-serving"
}

# Function to delete certificate objects
delete_cert_objects() {
    oc delete secret -n openshift-etcd $(get_etcd_cert_objects)
}

# Function to wait for new secrets to be created
wait_for_new_secrets() {
    sleep 15
    oc get secret -n openshift-etcd $(get_etcd_cert_objects)
}

# Function to review certificate expiration dates
review_cert_expiration() {
    local cert_objects="$1"
    for cert_name in $cert_objects; do
        oc get secret "$cert_name" -n openshift-etcd -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -noout -dates && echo '-----'
    done
}

# Main method
main() {
    local cert_objects="$(get_etcd_cert_objects)"
    delete_cert_objects
    wait_for_new_secrets
    review_cert_expiration "$cert_objects"
}

# Execute main method
main

