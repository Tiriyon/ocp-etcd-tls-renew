#!/bin/bash

# Define paths for CA certificates and their keys
read -r signers_dir < exported_vars.env
ETCD_SIGNER_CERT="$signers_dir/etcd-signer.crt"
ETCD_SIGNER_KEY="$signers_dir/etcd-signer.key"
ETCD_METRIC_SIGNER_CERT="$signers_dir/etcd-metric-signer.crt"
ETCD_METRIC_SIGNER_KEY="$signers_dir/etcd-metric-signer.key"



# Define the OpenSSL config file location
OPENSSL_CNF="/etc/pki/tls/openssl.cnf"

# Create a new directory for the new certificates
mkdir -p new-certs

# Function to extract SANs from an existing certificate
extract_sans() {
    local cert_path=$1
    if [ ! -f "$cert_path" ]; then
        echo "Certificate file not found: $cert_path"
        return 1
    fi
    openssl x509 -noout -ext "subjectAltName" -in "$cert_path" | grep -v X509v3 | sed 's/^ *//;s/ Address//g'
}

# Function to create and sign a certificate
create_and_sign_cert() {
    local cert_type=$1
    local hostname=$2

    echo "Processing $cert_type certificate for $hostname..."

    local source_dir="./etcd-all-$cert_type"
    local source_cert="$source_dir/etcd-$cert_type-$hostname.crt"
    local sans=$(extract_sans "$source_cert") || return

    local target_dir="./new-certs/etcd-all-$cert_type"
    mkdir -p "$target_dir"
    local target_key="$target_dir/etcd-$cert_type-$hostname.key"
    local target_csr="$target_dir/etcd-$cert_type-$hostname.csr"
    local target_cert="$target_dir/etcd-$cert_type-$hostname.crt"

    local ca_cert=""
    local ca_key=""

    if [[ "$cert_type" == "serving-metrics" ]]; then
        ca_cert=$ETCD_METRIC_SIGNER_CERT
        ca_key=$ETCD_METRIC_SIGNER_KEY
    else
        ca_cert=$ETCD_SIGNER_CERT
        ca_key=$ETCD_SIGNER_KEY
    fi

    openssl genrsa -out "$target_key" 2048
    openssl req -new -sha256 -key "$target_key" -subj "/CN=system:etcd-$cert_type:$hostname/O=system:etcd-$cert_type" \
        -reqexts SAN -config <(cat "$OPENSSL_CNF" <(printf "\n[SAN]\nsubjectAltName=%s\nbasicConstraints=critical,CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth" "$sans")) \
        -out "$target_csr"

    openssl x509 -req -in "$target_csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial \
        -out "$target_cert" -days 2000 \
        -extfile <(printf "subjectAltName=%s\nbasicConstraints=critical,CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth" "$sans")

    echo "Certificate for $cert_type on $hostname created and signed, with SANs: $sans."
}

# Read from nodes.env and process each node
while IFS= read -r line; do
    hostname=$(echo "$line" | awk '{print $1}')
    create_and_sign_cert "peer" "$hostname"
    create_and_sign_cert "serving" "$hostname"
    create_and_sign_cert "serving-metrics" "$hostname"
done < nodes.env
