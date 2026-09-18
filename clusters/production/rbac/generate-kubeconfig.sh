#!/bin/bash
# Generate a scoped kubeconfig for developer ServiceAccount (omega)
# Usage: ./generate-kubeconfig.sh [sa-name] [primary-namespace] [secondary-namespace]
# Default: ./generate-kubeconfig.sh omega omega-dev simple-hub-omega

set -euo pipefail

SA_NAME="${1:-omega}"
PRIMARY_NS="${2:-omega-dev}"
SECONDARY_NS="${3:-simple-hub-omega}"

CLUSTER_NAME="default"
SERVER=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="default")].cluster.server}')
OUTPUT_FILE="${SA_NAME}-kubeconfig.yaml"

echo "=== Generating unified kubeconfig for ${SA_NAME} ==="

# 1. Get cluster CA certificate
echo "[1/3] Fetching cluster CA certificate..."
CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="default")].cluster.certificate-authority-data}')

# 2. Create long-lived token (1 year) from primary ServiceAccount
echo "[2/3] Creating ServiceAccount token (365 days) for ${SA_NAME} in ${PRIMARY_NS}..."
TOKEN=$(kubectl create token "${SA_NAME}" \
  --namespace "${PRIMARY_NS}" \
  --duration=8760h)

# 3. Generate unified kubeconfig with contexts for both namespaces
echo "[3/3] Generating unified kubeconfig file..."
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
      namespace: ${PRIMARY_NS}
      user: ${SA_NAME}
    name: ${PRIMARY_NS}
  - context:
      cluster: ${CLUSTER_NAME}
      namespace: ${SECONDARY_NS}
      user: ${SA_NAME}
    name: ${SECONDARY_NS}
current-context: ${PRIMARY_NS}
users:
  - name: ${SA_NAME}
    user:
      token: ${TOKEN}
EOF

echo ""
echo "Done! Kubeconfig saved to: ${OUTPUT_FILE}"
echo ""
echo "Included Namespaces & Contexts:"
echo "  - ${PRIMARY_NS} (default)"
echo "  - ${SECONDARY_NS}"
echo ""
echo "Instructions for developer:"
echo "  1. Use default namespace: kubectl get pods"
echo "  2. Access secondary namespace: kubectl get pods -n ${SECONDARY_NS}"
echo "  3. Switch context: kubectl config use-context ${SECONDARY_NS}"
echo ""
