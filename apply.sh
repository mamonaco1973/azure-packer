#!/bin/bash


./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


cd 01-infrastructure
terraform init
terraform apply -auto-approve
cd ..

vault=$(az keyvault list --resource-group packer-rg --query "[?starts_with(name, 'packer-kv')].name | [0]" --output tsv)
echo "NOTE: Key vault for secrets is $vault"
secretsJson=$(az keyvault secret show --name packer-credentials --vault-name ${vault} --query value -o tsv)
password=$(echo "$secretsJson" | jq -r '.password')
 

cd 02-packer
cd linux


packer init .

packer build \
  -var="client_id=$ARM_CLIENT_ID" \
  -var="client_secret=$ARM_CLIENT_SECRET" \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="tenant_id=$ARM_TENANT_ID" \
  -var="password=$password" \
  linux_image.pkr.hcl

cd ..

cd ..

