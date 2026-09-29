#!/usr/bin/env bash
set -euo pipefail

: "${CODEARTIFACT_DOMAIN:?Defina CODEARTIFACT_DOMAIN}"
: "${CODEARTIFACT_REPOSITORY:?Defina CODEARTIFACT_REPOSITORY}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"

endpoint="$(aws codeartifact get-repository-endpoint \
  --domain "$CODEARTIFACT_DOMAIN" \
  --domain-owner "$AWS_ACCOUNT_ID" \
  --repository "$CODEARTIFACT_REPOSITORY" \
  --format npm \
  --region "$AWS_REGION" \
  --query repositoryEndpoint \
  --output text)"

token="$(aws codeartifact get-authorization-token \
  --domain "$CODEARTIFACT_DOMAIN" \
  --domain-owner "$AWS_ACCOUNT_ID" \
  --region "$AWS_REGION" \
  --query authorizationToken \
  --output text)"

host="${endpoint#https://}"
config_path="$(mktemp)"
chmod 600 "$config_path"
trap 'rm -f "$config_path"' EXIT

printf 'registry=%s/\n//%s/:_authToken=%s\n' "$endpoint" "$host" "$token" > "$config_path"

pushd "$(dirname "$0")/../codeartifact-demo" > /dev/null
npm publish --userconfig "$config_path" --registry "$endpoint/"
popd > /dev/null
