#!/usr/bin/env bash
# =============================================================================
# Image Scanning Script - DHI Workshop
# =============================================================================
# This script scans container images for vulnerabilities using Trivy
#
# Usage:
#   ./scripts/scan-image.sh <image-name> [output-file]
#
# Examples:
#   ./scripts/scan-image.sh node:20-bookworm
#   ./scripts/scan-image.sh demonstrationorg/dhi-node:22-alpine3.22
#   ./scripts/scan-image.sh demonstrationorg/dhi-nginx:1.28.0-alpine3.21-dev
#   ./scripts/scan-image.sh dhi-workshop-app-dhi trivy-results.json
#
# Requirements:
#   - Trivy must be installed (https://github.com/aquasecurity/trivy)
#   - Docker must be running
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if Trivy is installed
if ! command -v trivy &> /dev/null; then
    echo -e "${RED}Error: Trivy is not installed${NC}"
    echo ""
    echo "Install Trivy:"
    echo "  macOS:   brew install aquasecurity/trivy/trivy"
    echo "  Linux:   wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -"
    echo "           echo 'deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main' | sudo tee -a /etc/apt/sources.list.d/trivy.list"
    echo "           sudo apt-get update && sudo apt-get install trivy"
    echo "  Docker:  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <image>"
    exit 1
fi

# Check if image name is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No image name provided${NC}"
    echo ""
    echo "Usage: $0 <image-name> [output-file]"
    echo ""
    echo "Examples:"
    echo "  $0 node:20-bookworm"
    echo "  $0 demonstrationorg/dhi-node:22-alpine3.22"
    echo "  $0 dhi-workshop-app-dhi trivy-doi-results.json"
    exit 1
fi

IMAGE="$1"
OUTPUT_FILE="${2:-}"

echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}    Scanning Image: ${IMAGE}${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# Pull the image if it's not local
echo -e "${YELLOW}Ensuring image is available locally...${NC}"
docker pull "$IMAGE" 2>&1 | grep -E "(Digest|Status|Image is up to date)" || true
echo ""

# Scan with Trivy
echo -e "${YELLOW}Running Trivy scan (HIGH and CRITICAL vulnerabilities)...${NC}"
echo ""

if [ -n "$OUTPUT_FILE" ]; then
    echo -e "${BLUE}Saving results to: ${OUTPUT_FILE}${NC}"
    echo ""

    # Save to file (JSON format for parsing)
    trivy image \
        --severity HIGH,CRITICAL \
        --no-progress \
        --format json \
        -o "$OUTPUT_FILE" \
        "$IMAGE"

    # Also display table format to terminal
    trivy image \
        --severity HIGH,CRITICAL \
        --no-progress \
        --format table \
        "$IMAGE"

    echo ""
    echo -e "${GREEN}Results saved to: ${OUTPUT_FILE}${NC}"
else
    # Terminal output only
    trivy image \
        --severity HIGH,CRITICAL \
        --no-progress \
        --format table \
        "$IMAGE"
fi

echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}Scan complete!${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# Additional information
echo -e "${BLUE}Additional scan options:${NC}"
echo ""
echo -e "${GREEN}Save results to file (JSON):${NC}"
echo "  trivy image --severity HIGH,CRITICAL --format json -o trivy-results.json $IMAGE"
echo ""
echo -e "${GREEN}Save results to file (Table):${NC}"
echo "  trivy image --severity HIGH,CRITICAL --format table -o trivy-results.txt $IMAGE"
echo ""
echo -e "${GREEN}Include MEDIUM severity:${NC}"
echo "  trivy image --severity MEDIUM,HIGH,CRITICAL $IMAGE"
echo ""
echo -e "${GREEN}Generate SARIF output for GitHub Actions:${NC}"
echo "  trivy image --format sarif -o trivy-results.sarif $IMAGE"
echo ""
echo -e "${GREEN}Compare with Docker Scout (save to file):${NC}"
echo "  docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22 --format markdown > scout-comparison.md"
echo ""
