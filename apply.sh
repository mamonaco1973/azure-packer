#!/bin/bash
# ==============================================================================
# AZURE PACKER + TERRAFORM PIPELINE
# ==============================================================================
#
# Master automation script for provisioning infrastructure, building VM images
# using Packer, and deploying resources with Terraform on Azure.
#
# Assumes the environment is pre-authenticated (e.g., via `az login`) and that
# required tools (az, terraform, packer, jq) are installed and available.
# ==============================================================================

# ------------------------------------------------------------------------------
# Strict shell behavior
# ------------------------------------------------------------------------------
# -e         Exit immediately if any command fails
# -u         Treat unset variables as errors
# -o pipefail  Fail if any command in a pipeline fails
# ------------------------------------------------------------------------------
set -euo pipefail

# ==============================================================================
# STEP 1: VALIDATE ENVIRONMENT AND PREREQUISITES
# ==============================================================================
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ==============================================================================
# STEP 2: PROVISION BASE INFRASTRUCTURE (VNET, SUBNET, NSG, PACKER PASSWORD)
# ==============================================================================
cd 01-infrastructure
terraform init
terraform apply -auto-approve

# ==============================================================================
# STEP 3: READ THE PACKER PASSWORD FROM TERRAFORM STATE
# ==============================================================================
password=$(terraform output -raw packer_password)
cd ..

if [ -z "$password" ]; then
  echo "ERROR: Failed to read the packer password from Terraform state."
  exit 1
fi

# ==============================================================================
# STEP 4: BUILD CUSTOM IMAGES WITH PACKER
# ==============================================================================
#
# This step builds both:
# - Linux image:  games_image_YYYYMMDDHHMMSS
# - Windows image: desktop_image_YYYYMMDDHHMMSS
# ==============================================================================

# ---- STEP 4A: Build custom Linux image ---------------------------------------
cd 02-packer/linux
packer init .
packer build \
 -var="client_id=$ARM_CLIENT_ID" \
 -var="client_secret=$ARM_CLIENT_SECRET" \
 -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
 -var="tenant_id=$ARM_TENANT_ID" \
 -var="password=$password" \
 -var="resource_group=packer-rg" \
 linux_image.pkr.hcl
cd ..

# ---- STEP 4B: Build custom Windows image -------------------------------------
cd windows
packer init .
packer build \
 -var="client_id=$ARM_CLIENT_ID" \
 -var="client_secret=$ARM_CLIENT_SECRET" \
 -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
 -var="tenant_id=$ARM_TENANT_ID" \
 -var="password=$password" \
 -var="resource_group=packer-rg" \
 windows_image.pkr.hcl
cd ../..

# ==============================================================================
# STEP 5: RESOLVE LATEST MANAGED IMAGES FOR DEPLOYMENT
# ==============================================================================
games_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'games_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using the latest games image ($games_image_name) in packer-rg."

if [ -z "$games_image_name" ]; then
  echo "ERROR: No image with prefix 'games_image' found in 'packer-rg'. Exiting."
  exit 1
fi

desktop_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'desktop_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using the latest desktop image ($desktop_image_name) in packer-rg."

if [ -z "$desktop_image_name" ]; then
  echo "ERROR: No image with prefix 'desktop_image' found in 'packer-rg'. Exiting."
  exit 1
fi

# ==============================================================================
# STEP 6: DEPLOY FINAL VMS USING TERRAFORM AND LATEST IMAGES
# ==============================================================================
cd 03-deploy
terraform init
terraform apply \
  -var="games_image_name=$games_image_name" \
  -var="desktop_image_name=$desktop_image_name" \
  -auto-approve
cd ..

./validate.sh

# ==============================================================================
# END OF SCRIPT
# ==============================================================================
