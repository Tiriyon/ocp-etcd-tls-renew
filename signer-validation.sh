#!/bin/bash

read -r signers_dir < "exported_vars.env" 

# List of signers to extract certs and keys for
signers=("etcd-signer" "etcd-metric-signer")

# Extract certificates and keys
for signer in "${signers[@]}"; do
  echo "Validating for $signer"

  # Extract the certificate
  cert_path="$signers_dir/$signer.crt"
  key_path="$signers_dir/$signer.key"


  # Validate the certificate
  if openssl x509 -in "$cert_path" -noout -text; then
    echo "$signer certificate is valid and stored at $cert_path"
  else
    echo "Error: $signer certificate is invalid or extraction failed"
  fi

  # Check for key's existence
  if [ -s "$key_path" ]; then
    echo "$signer key is stored at $key_path"
  else
    echo "Error: $signer key extraction failed or the key is empty"
  fi
done

echo "Validation process completed. Check $signers_dir for certificates and keys."
