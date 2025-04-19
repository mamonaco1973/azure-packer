games_image_name=$(az image list --resource-group packer-rg --query "[?starts_with(name, 'games_image')]|sort_by(@, &name)[-1].name" --output tsv)

echo "NOTE: Using the latest image ($games_image_name) in packer-rg."

# Check if image_name is empty and exit with error if no image is found
if [ -z "$games_image_name" ]; then
  echo "ERROR: No image with the prefix 'games_image' was found in the resource group 'packer-rg'. Exiting."
  exit 1
fi

cd 03-deploy
terraform init
terraform apply -var="games_image_name=$games_image_name" -auto-approve
cd ..


