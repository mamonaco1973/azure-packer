#!/bin/bash
# ==============================================================================
# validate.sh — print what you need to try the lab
#
# Both VMs are public: the games VM answers on HTTP, the Windows desktop VM
# on RDP. Both images carry the packer account, whose password get_password.sh
# reads from the 01-infrastructure Terraform state.
# ==============================================================================

set -euo pipefail

get_fqdn_by_pip_name() {
  az network public-ip show \
    --resource-group packer-rg \
    --name "$1" \
    --query dnsSettings.fqdn \
    --output tsv 2>/dev/null || true
}

games_fqdn=$(get_fqdn_by_pip_name "games-pip")
desktop_fqdn=$(get_fqdn_by_pip_name "desktop-pip")

echo ""
echo "============================================================================"
echo "Packer Images - Validation Output"
echo "============================================================================"
echo ""

if [ -n "${games_fqdn}" ]; then
  printf "NOTE: %-22s %s\n" "Games URL:" "http://${games_fqdn}"
else
  printf "WARN: %-22s %s\n" "Games VM:" "not found"
fi

if [ -n "${desktop_fqdn}" ]; then
  printf "NOTE: %-22s %s\n" "Windows VM (RDP):" "${desktop_fqdn}"
else
  printf "WARN: %-22s %s\n" "Windows VM (RDP):" "not found"
fi
echo ""

"$(dirname "$0")/get_password.sh"
echo ""
