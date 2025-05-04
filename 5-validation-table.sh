#!/bin/bash

# Define paths for certificate directories
original_dir_prefix="etcd-all"
new_dir_prefix="new-certs"
safe_send(){ f=$(mktemp -u); mkfifo $f; { (sleep ${1:-1}; echo >&3) } 3>$f & read -t ${1:-1} < $f; rm $f; }

# Define the output text file
output_file1="certificate_comparison1.txt"
output_file2="certificate_comparison2.txt"
output_file3="certificate_comparison3.txt"

# Clear the output file
> "$output_file1"
> "$output_file2"
> "$output_file3"

# Function to extract and format certificate details
extract_and_format_details() {
    local cert_path=$1
    # Extract SANs
    local sans=$(openssl x509 -noout -ext "subjectAltName" -in "$cert_path" 2>/dev/null | grep -v X509v3 | sed 's/^ *//;s/ Address//g')
    # Extract Issuer
    local issuer=$(openssl x509 -noout -issuer -in "$cert_path" | sed 's/issuer= *//')
    # Extract Subject
    local subject=$(openssl x509 -noout -subject -in "$cert_path" | sed 's/subject= *//')
    # Combine details
    echo "Cert: $cert_path | SANs: $sans | Issuer: $issuer | Subject: $subject"
    safe_send 3
}

# Loop through each type of certificates
for type in peer serving serving-metrics; do
    original_dir="${original_dir_prefix}-${type}"
    new_dir="${new_dir_prefix}/etcd-all-${type}"
    echo "$new_dir $original_dir"
    # Ensure directory exists
    if [[ ! -d "$original_dir" || ! -d "$new_dir" ]]; then
        echo "Directory missing for $type, skipping..."
        continue
    fi

    # Process each original certificate
    for original_cert in "$original_dir"/*.crt; do
        hostname=$(basename "$original_cert" .crt)
        new_cert="$new_dir/$hostname.crt"
        echo "$new_cert"
        echo "$original_cert"

        if [[ -f "$new_cert" ]]; then
            # Extract and format details from both certificates
            original_details=$(extract_and_format_details "$original_cert")
            new_details=$(extract_and_format_details "$new_cert")

            # Write to text file
            echo "$original_details" >> "$output_file1"
            echo "$new_details" >> "$output_file1"
            #echo "" >> "$output_file"  # add a blank line for separation
        else
            echo "Missing new certificate for $hostname, not comparing." >> "$output_file3"
        fi
        safe_send 3
    done
done

echo "Comparison completed. Results are saved in $output_file1."
