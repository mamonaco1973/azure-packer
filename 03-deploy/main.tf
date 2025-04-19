# Define the AzureRM provider
provider "azurerm" {
  features {}                                         # Enable all default features
}

# Retrieve subscription information
data "azurerm_subscription" "primary" {}

# Retrieve current client configuration
data "azurerm_client_config" "current" {}


# Retrieve the resource group details
data "azurerm_resource_group" "packer_rg" {
  name = "packer-rg"                              
}

# Retrieve the latest Azure image from the resource group
data "azurerm_image" "games_image" {
  name                = var.games_image_name                                 # Name of the custom image
  resource_group_name = data.azurerm_resource_group.packer_rg.name # Resource group for the image
}

# Retrieve the virtual network details
data "azurerm_virtual_network" "packer_vnet" {
  name                = "packer-vnet"                               
  resource_group_name = data.azurerm_resource_group.packer_rg.name 
}

# Retrieve the subnet details
data "azurerm_subnet" "packer_subnet" {
  name                 = "packer-subnet"                               # Subnet name
  virtual_network_name = data.azurerm_virtual_network.packer_vnet.name # Parent VNet name
  resource_group_name  = data.azurerm_resource_group.packer_rg.name    # Resource group name
}


