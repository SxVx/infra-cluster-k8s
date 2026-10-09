#!/usr/bin/env bash
# Regenerates the kubeconfig for the Spot cluster with a fresh token and activates its context.
#
# The token inside Spot's kubeconfig is short-lived, and `terraform output` only returns what is
# stored in state. Refreshing state first makes the data source request a new token.
#
# Configuration (environment variables):
#   SPOT_ENV_FILE    file that defines TF_VAR_rackspace_spot_token (default: ~/.config/rackspace/spot.env)
#   SPOT_KUBECONFIG  output kubeconfig path                        (default: ~/.kube/spot-portafolio.yaml)
#   SPOT_CONTEXT     context name to use                           (default: portafolio)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_dir="$repo_root/terraform/spot-cluster"
env_file="${SPOT_ENV_FILE:-$HOME/.config/rackspace/spot.env}"
out="${SPOT_KUBECONFIG:-$HOME/.kube/spot-portafolio.yaml}"
context="${SPOT_CONTEXT:-portafolio}"

if [[ ! -r "$env_file" ]]; then
  echo "error: $env_file not found; it must define TF_VAR_rackspace_spot_token" >&2
  exit 1
fi

# 1. Refresh state. The token is only loaded inside this subshell.
(
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
  terraform -chdir="$tf_dir" apply -refresh-only -auto-approve -input=false >/dev/null
)

# 2. Write to a temp file and replace atomically, so a failure never breaks the current kubeconfig.
mkdir -p "$(dirname "$out")"
tmp="$(mktemp "$(dirname "$out")/.spot.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"
terraform -chdir="$tf_dir" output -raw kubeconfig >"$tmp"
kubectl --kubeconfig "$tmp" config rename-context \
  "$(kubectl --kubeconfig "$tmp" config current-context)" "$context" >/dev/null
mv "$tmp" "$out"
trap - EXIT

# 3. Activate the context (KUBECONFIG must include $out).
kubectl config use-context "$context"
