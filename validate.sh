#!/usr/bin/env bash

# ================================================================================================
# VALIDATE SCRIPT: DISPLAY DEPLOYED VM FQDNS
# ================================================================================================
# This script retrieves key Terraform outputs and prints them in a human-readable format.
# It is intended to be run after a successful `terraform apply`.
# ================================================================================================

set -euo pipefail
cd 03-deploy

# --------------------------------------------------------------------------------
# VERIFY TERRAFORM IS INITIALIZED
# --------------------------------------------------------------------------------
if [ ! -d ".terraform" ]; then
  echo "ERROR: Terraform is not initialized in this directory."
  echo "Run 'terraform init' before executing this script."
  exit 1
fi

# --------------------------------------------------------------------------------
# RETRIEVE TERRAFORM OUTPUTS
# --------------------------------------------------------------------------------
DESKTOP_VM_FQDN=$(terraform output -raw desktop_vm_fqdn)
GAMES_VM_FQDN=$(terraform output -raw games_vm_fqdn)

# --------------------------------------------------------------------------------
# DISPLAY RESULTS
# --------------------------------------------------------------------------------
echo "============================================================"
echo " Azure Virtual Machine Endpoints"
echo "============================================================"
echo
echo " Desktop VM FQDN:"
echo "   ${DESKTOP_VM_FQDN}"
echo
echo " Games VM FQDN:"
echo "   ${GAMES_VM_FQDN}"
echo "   http://${GAMES_VM_FQDN}"
echo
echo "============================================================"
cd ..
