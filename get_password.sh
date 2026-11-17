#!/bin/bash
# ==============================================================================
# get_password.sh — print the packer user and its password
#
# The password is the random_password generated in 01-infrastructure, so it
# is read from that phase's Terraform state through its packer_password
# output.
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")/01-infrastructure"

if [ ! -f terraform.tfstate ]; then
  echo "ERROR: No Terraform state in 01-infrastructure. Run apply.sh first."
  exit 1
fi

password=$(terraform output -raw packer_password 2>/dev/null || true)

if [ -z "${password}" ] || [ "${password}" = "null" ]; then
  echo "ERROR: packer_password not found in Terraform state."
  exit 1
fi

printf "NOTE: %-22s %s\n" "Packer user:" "packer"
printf "NOTE: %-22s %s\n" "Packer password:" "${password}"
