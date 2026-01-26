#!/bin/bash
# ==============================================================================
# AZURE TEARDOWN: DESTROY TERRAFORM STACK AND DELETE CUSTOM IMAGES
# ==============================================================================
#
# This script tears down the full Azure environment created by the project.
# It performs the following high-level actions:
# - Authenticates to Azure using a Service Principal
# - Resolves the latest custom managed images for Linux and Windows
# - Destroys the VM deployment layer that references those images
# - Deletes all managed images from the packer resource group
# - Destroys the base infrastructure layer (networking, bastion, key vault, etc.)
#
# Notes:
# - This script is destructive and cannot be undone.
# - Images must be deleted after dependent resources are destroyed.
# - Ensure ARM_* environment variables are set before running this script.
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
# STEP 1: AUTHENTICATE TO AZURE (SERVICE PRINCIPAL)
# ==============================================================================
#
# Authenticate using a Service Principal. Output is suppressed to avoid clutter
# and prevent accidental credential disclosure in terminal logs.
# ==============================================================================

az login \
  --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID" \
  > /dev/null 2>&1

# ==============================================================================
# STEP 2: RESOLVE LATEST MANAGED IMAGES FOR DESTROY
# ==============================================================================
#
# The deployment stack takes image names as Terraform input variables.
# Resolve the latest images by sorting on name, which includes timestamps.
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
# STEP 3: DESTROY VM DEPLOYMENT LAYER (03-DEPLOY)
# ==============================================================================
#
# Destroy the final deployment resources that depend on the managed images.
# The image names are passed so Terraform can properly resolve dependencies.
# ==============================================================================

cd 03-deploy
terraform init
terraform destroy \
  -var="games_image_name=$games_image_name" \
  -var="desktop_image_name=$desktop_image_name" \
  -auto-approve
cd ..

# ==============================================================================
# STEP 4: DELETE ALL MANAGED IMAGES FROM packer-rg
# ==============================================================================
#
# Remove all managed images in the packer resource group. This is performed
# after the deployment layer is destroyed to avoid dependency conflicts.
#
# Notes:
# - This deletes all images, not only games/desktop images.
# - Failures are logged and the loop continues.
# ==============================================================================

az image list \
  --resource-group "packer-rg" \
  --query "[].name" \
  --output tsv | while read -r IMAGE; do
    echo "Deleting image: $IMAGE"
    az image delete \
      --name "$IMAGE" \
      --resource-group "packer-rg" \
      || echo "WARNING: Failed to delete $IMAGE (continuing)"
done

# ==============================================================================
# STEP 5: DESTROY BASE INFRASTRUCTURE LAYER (01-INFRASTRUCTURE)
# ==============================================================================
#
# Destroy foundational resources such as networking, subnets, NSGs, Bastion,
# Key Vault, and any supporting components created in the infrastructure layer.
# ==============================================================================

cd 01-infrastructure
terraform init
terraform destroy -auto-approve
cd ..

# ==============================================================================
# END OF SCRIPT
# ==============================================================================
