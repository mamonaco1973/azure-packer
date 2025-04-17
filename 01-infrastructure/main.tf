# Configure the Azure Provider
provider "azurerm" {
  features {} # Enables all optional features in the Azure provider
}

# Retrieve the Azure subscription details
data "azurerm_subscription" "primary" {}

# Retrieve the Azure client configuration for authentication
data "azurerm_client_config" "current" {}

# Define the resource group for the deployment
resource "azurerm_resource_group" "flask-vmss" {
  name     = "packer-rg"           # Name of the resource group
  location = "Central US"          # Azure region for the resource group
}
