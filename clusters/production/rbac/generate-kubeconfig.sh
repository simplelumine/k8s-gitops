#!/bin/bash
# Generate a scoped kubeconfig for a developer ServiceAccount
# Usage: ./generate-kubeconfig.sh <sa-name> <namespace>
# Example: ./generate-kubeconfig.sh omega omega-dev

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <service-account-name> <namespace>"
  echo "Example: $0 omega omega-dev"
  exit 1
fi

SA_NAME="$1"
NAMESPACE="$2"
CLUSTER_NAME="gitops"
SERVER=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="gitops")].cluster.server}')
OUTPUT_FILE="${SA_NAME}-kubeconfig.yaml"

echo "=== Generating kubeconfig for ${SA_NAME} ==="

# 1. Get cluster CA certificate
echo "[1/3] Fetching cluster CA certificate..."
CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="gitops")].cluster.certificate-authority-data}')

# 2. Create long-lived token (1 year)
echo "[2/3] Creating ServiceAccount token (365 days)..."
TOKEN=$(kubectl create token "${SA_NAME}" \
  --namespace "${NAMESPACE}" \
  --duration=8760h)

# 3. Generate kubeconfig file
echo "[3/3] Generating kubeconfig file..."
cat > "${OUTPUT_FILE}" <<EOF
apiVersion: v1
kind: Config
clusters:
  - cluster:
      certificate-authority-data: ${CA_DATA}
      server: ${SERVER}
    name: ${CLUSTER_NAME}
contexts:
  - context:
      cluster: ${CLUSTER_NAME}
      namespace: ${NAMESPACE}
      user: ${SA_NAME}
    name: ${SA_NAME}@${CLUSTER_NAME}
current-context: ${SA_NAME}@${CLUSTER_NAME}
users:
  - name: ${SA_NAME}
    user:
      token: ${TOKEN}
EOF

echo ""
echo "Done! Kubeconfig saved to: ${OUTPUT_FILE}"
echo ""
echo "Instructions:"
echo "  1. Send ${OUTPUT_FILE} to the developer"
echo "  2. Place it at ~/.kube/config (or set KUBECONFIG env variable)"
echo "  3. Test connection: kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Note: Token expires in 1 year. Re-run this script to regenerate."
