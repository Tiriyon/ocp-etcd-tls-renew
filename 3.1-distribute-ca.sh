#!/bin/bash

# Load signer paths
read -r signers_dir < exported_vars.env
ETCD_SIGNER_CERT="$signers_dir/etcd-signer.crt"
ETCD_METRIC_SIGNER_CERT="$signers_dir/etcd-metric-signer.crt"

# Source directory for newly generated certificates
NEW_CERTS_DIR="./new-certs"

echo "Bundling signer certificates into new etcd certificates..."

# Process each certificate
find "$NEW_CERTS_DIR" -type f -name "*.crt" | while read -r cert_file; do
    # Determine cert type by its path
    if echo "$cert_file" | grep -q "serving-metrics"; then
        signer_cert="$ETCD_METRIC_SIGNER_CERT"
    else
        signer_cert="$ETCD_SIGNER_CERT"
    fi

    echo "Bundling signer into: $cert_file"

    # Create a temp file
    tmpfile=$(mktemp)

    # Concatenate cert and signer
    cat "$cert_file" "$signer_cert" > "$tmpfile"
    mv "$tmpfile" "$cert_file"
done

echo "Bundling complete. All certificates now include their signer CA."

