#!/usr/bin/env bash
# Prints a base64 kubeconfig for an app's `ci-deployer` ServiceAccount, ready to paste as the
# KUBE_CONFIG secret of the app repo's `production` GitHub environment.
#
#   scripts/ci-kubeconfig.sh personal-web | pbcopy
#
# The ServiceAccount token is long-lived, but the API endpoint changes on every
# `terraform destroy/apply`: re-run this script and update the secret afterwards.
#
# Configuration (environment variables):
#   SPOT_CONTEXT  admin context used to read the token (default: portafolio)
set -euo pipefail

ns="${1:?usage: $0 <namespace>}"
context="${SPOT_CONTEXT:-portafolio}"
k() { kubectl --context "$context" "$@"; }

cluster="$(k config view --minify --raw -o jsonpath='{.contexts[0].context.cluster}')"
server="$(k config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')"
ca="$(k config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
token="$(k -n "$ns" get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 --decode)"

if [[ -z "$token" ]]; then
  echo "error: no token in $ns/ci-deployer-token; apply k8s/$ns/ first" >&2
  exit 1
fi

if [[ -n "$ca" ]]; then
  tls="certificate-authority-data: ${ca}"
else
  echo "warning: admin context has no CA data; using insecure-skip-tls-verify" >&2
  tls="insecure-skip-tls-verify: true"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"
cat >"$tmp" <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: ${cluster}
    cluster:
      server: ${server}
      ${tls}
users:
  - name: ci-deployer
    user:
      token: ${token}
contexts:
  - name: ci-deployer
    context:
      cluster: ${cluster}
      user: ci-deployer
      namespace: ${ns}
current-context: ci-deployer
YAML

# Sanity check (stderr): allowed here, denied elsewhere.
echo "patch deployments in $ns: $(kubectl --kubeconfig "$tmp" auth can-i patch deployments -n "$ns" || true)" >&2
echo "get pods in kube-system:  $(kubectl --kubeconfig "$tmp" auth can-i get pods -n kube-system || true)" >&2

base64 <"$tmp" | tr -d '\n'
echo
