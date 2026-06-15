#!/usr/bin/env bash
# Bootstrap the SOPS decryption key in the cluster.
# Run ONCE per cluster, before `flux bootstrap` (or right after, before reconciling apps).
# Idempotent: re-runs are safe.

set -euo pipefail

KEY_FILE="${KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
NAMESPACE="${NAMESPACE:-flux-system}"
SECRET_NAME="${SECRET_NAME:-sops-age}"

if [ ! -f "$KEY_FILE" ]; then
  echo "✗ Age key file not found: $KEY_FILE"
  echo "  Generate one with:  age-keygen -o $KEY_FILE"
  echo "  Then make sure its public key matches the one in .sops.yaml."
  exit 1
fi

# Pull public key out of the file and compare with .sops.yaml — fail fast on mismatch.
PUB_IN_KEY="$(grep -E '^# public key:' "$KEY_FILE" | awk '{print $NF}')"
PUB_IN_SOPS="$(grep -E '^\s+age:' "$(dirname "$0")/../.sops.yaml" | head -1 | awk '{print $NF}')"

if [ "$PUB_IN_KEY" != "$PUB_IN_SOPS" ]; then
  echo "✗ Public key mismatch:"
  echo "    $KEY_FILE → $PUB_IN_KEY"
  echo "    .sops.yaml → $PUB_IN_SOPS"
  echo "  Flux will not be able to decrypt secrets with this key."
  exit 1
fi

kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
  --from-file=age.agekey="$KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret $NAMESPACE/$SECRET_NAME is in place."
echo "  Flux Kustomizations referencing decryption.secretRef.name=$SECRET_NAME can now decrypt SOPS files."
