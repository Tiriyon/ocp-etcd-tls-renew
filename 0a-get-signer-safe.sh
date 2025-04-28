#!/bin/bash

# --- Config ---
namespace="openshift-config"
signers=("etcd-signer" "etcd-metric-signer")
local_root_certs_dir="./etcd-signers-$(date +%Y%m%d)"
mkdir -p "$local_root_certs_dir"

# --- Check oc available ---
if ! command -v oc &> /dev/null; then
  echo "❌ 'oc' command not found. Install OpenShift CLI first."
  exit 1
fi

# --- Extract signer certs and keys ---
for signer in "${signers[@]}"; do
  echo "Processing signer: $signer..."
  
  # Check if secret exists
  if ! oc get secret "$signer" -n "$namespace" &> /dev/null; then
    echo "⚠️  Warning: Secret '$signer' not found in namespace '$namespace'. Skipping."
    continue
  fi

  # Extract and decode cert
  oc get secret "$signer" -n "$namespace" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$local_root_certs_dir/$signer.crt"
  
  # Extract and decode key
  oc get secret "$signer" -n "$namespace" -o jsonpath='{.data.tls\.key}' | base64 -d > "$local_root_certs_dir/$signer.key"

  echo "✅ Extracted $signer.crt and $signer.key"
done

# --- Export path for downstream scripts ---
echo "$local_root_certs_dir" > exported_vars.env

echo "🏁 Extraction complete. Certificates and keys stored in: $local_root_certs_dir"

