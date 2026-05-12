#!/usr/bin/env bash
# Generate RSA keys, build K8s Secret YAMLs from local .env files,
# SOPS-encrypt them into apps/secrets/.
#
# Idempotent: keys are cached in ~/.cache/casego-secrets/.
# Run after editing ~/Case_go/CaseGo/*/.env or to refresh secrets.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$REPO_DIR/apps/secrets"
CACHE_DIR="$HOME/.cache/casego-secrets"
AUTH_ENV="${AUTH_ENV:-$HOME/Case_go/CaseGo/Auth/.env}"
CASEGO_ENV="${CASEGO_ENV:-$HOME/Case_go/CaseGo/CaseGo/.env}"

mkdir -p "$CACHE_DIR" "$SECRETS_DIR"

if [ ! -f "$CACHE_DIR/private.pem" ]; then
  echo "▶ Generating RSA keypair"
  openssl genpkey -algorithm RSA -out "$CACHE_DIR/private.pem" -pkeyopt rsa_keygen_bits:2048
  openssl pkey -in "$CACHE_DIR/private.pem" -pubout -out "$CACHE_DIR/public.pem"
  chmod 600 "$CACHE_DIR/private.pem"
fi

get_env() {
  local file="$1" key="$2"
  [ -f "$file" ] || { echo "" ; return; }
  grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-
}

GOOGLE_CLIENT_ID="$(get_env "$AUTH_ENV" GOOGLE_CLIENT_ID)"
OPENAI_API_KEY="$(get_env "$CASEGO_ENV" OPENAI_API_KEY)"
GIGACHAT_AUTH_KEY="$(get_env "$CASEGO_ENV" GIGACHAT_AUTH_KEY)"
LLM_URL="$(get_env "$CASEGO_ENV" LLM_URL)"
LLM_PROVIDER="$(get_env "$CASEGO_ENV" LLM_PROVIDER)"

[ -n "$GOOGLE_CLIENT_ID" ] || echo "⚠ GOOGLE_CLIENT_ID not found in $AUTH_ENV"
[ -n "$LLM_PROVIDER" ] || echo "⚠ LLM_PROVIDER not found in $CASEGO_ENV"

PUBLIC_KEY_ENV="$(awk 'NR>1{printf "\\n"} {printf "%s", $0}' "$CACHE_DIR/public.pem")"

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

cat > "$TMP/auth-jwt-keys.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: auth-jwt-keys
  namespace: casego-apps
type: Opaque
stringData:
  private.pem: |
$(sed 's/^/    /' "$CACHE_DIR/private.pem")
  public.pem: |
$(sed 's/^/    /' "$CACHE_DIR/public.pem")
EOF

cat > "$TMP/auth-oauth.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: auth-oauth
  namespace: casego-apps
type: Opaque
stringData:
  GOOGLE_CLIENT_ID: "${GOOGLE_CLIENT_ID}"
EOF

cat > "$TMP/casego-llm.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: casego-llm
  namespace: casego-apps
type: Opaque
stringData:
  GIGACHAT_AUTH_KEY: "${GIGACHAT_AUTH_KEY}"
  OPENAI_API_KEY: "${OPENAI_API_KEY}"
  LLM_URL: "${LLM_URL}"
  LLM_PROVIDER: "${LLM_PROVIDER}"
EOF

cat > "$REPO_DIR/apps/jwt-public-key-configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: jwt-public-key
  namespace: casego-apps
data:
  PUBLIC_KEY: "${PUBLIC_KEY_ENV}"
EOF

for f in auth-jwt-keys auth-oauth casego-llm; do
  echo "▶ SOPS-encrypting $f.yaml"
  cp "$TMP/$f.yaml" "$SECRETS_DIR/$f.yaml"
  sops --encrypt --in-place "$SECRETS_DIR/$f.yaml"
done

echo
echo "✓ Done."
echo "  Encrypted secrets → $SECRETS_DIR/"
echo "  Public key ConfigMap → $REPO_DIR/apps/jwt-public-key-configmap.yaml"
echo
echo "Review changes and commit:"
echo "  cd $REPO_DIR && git status"
