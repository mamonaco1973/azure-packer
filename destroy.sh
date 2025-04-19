#!/bin/bash

az login --service-principal --username "$ARM_CLIENT_ID" --password "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null 2>&1

games_image_name=$(az image list --resource-group packer-rg --query "[?starts_with(name, 'games_image')]|sort_by(@, &name)[-1].name" --output tsv)

echo "NOTE: Using the latest image ($games_image_name) in packer-rg."

# Check if image_name is empty and exit with error if no image is found
if [ -z "$games_image_name" ]; then
  echo "ERROR: No image with the prefix 'games_image' was found in the resource group 'packer-rg'. Exiting."
  exit 1
fi

cd 03-deploy
terraform init
terraform destroy -var="games_image_name=$games_image_name" -auto-approve
cd ..


# Delete all images in resource group "packer-rg" (non-interactive, errors ignored)

az image list --resource-group "packer-rg" --query "[].name" -o tsv | while read -r IMAGE; do
  echo "Deleting image: $IMAGE"
  az image delete --name "$IMAGE" --resource-group "packer-rg" || echo "Failed to delete $IMAGE — skipping"
done

cd 01-infrastructure
terraform init
terraform destroy -auto-approve
cd ..




