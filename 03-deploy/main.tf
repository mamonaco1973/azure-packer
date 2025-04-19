############################################
# AZURE PROVIDER CONFIGURATION
############################################
provider "azurerm" {
  features {}                                                                 # Enables all default provider features (required boilerplate)
}

############################################
# DATA SOURCES: AZURE CONTEXT & METADATA
############################################

# Retrieve details about the active Azure subscription
data "azurerm_subscription" "primary" {}                                      # Useful for referencing subscription ID, display name, etc.

# Retrieve details about the currently authenticated Azure client
data "azurerm_client_config" "current" {}                                     # Used to fetch tenant ID, object ID, client ID, and subscription

############################################
# RESOURCE GROUP: LOOKUP FOR EXISTING RG
############################################
data "azurerm_resource_group" "packer_rg" {
  name = "packer-rg"                                                          # Name of the existing resource group used for image and network
}

############################################
# CUSTOM IMAGE: LOOKUP FOR VM SOURCE IMAGE FOR GAMES
############################################
data "azurerm_image" "games_image" {
  name                = var.games_image_name                                 # Custom image name passed in as variable
  resource_group_name = data.azurerm_resource_group.packer_rg.name           # Use resource group where the image is stored
}

############################################
# CUSTOM IMAGE: LOOKUP FOR VM SOURCE IMAGE FOR DESKTOP
############################################
data "azurerm_image" "desktop_image" {
  name                = var.desktop_image_name                               # Custom image name passed in as variable
  resource_group_name = data.azurerm_resource_group.packer_rg.name           # Use resource group where the image is stored
}

############################################
# VIRTUAL NETWORK: LOOKUP FOR NETWORK CONTEXT
############################################
data "azurerm_virtual_network" "packer_vnet" {
  name                = "packer-vnet"                                        # Name of the existing virtual network to use
  resource_group_name = data.azurerm_resource_group.packer_rg.name           # Must be in the same resource group as the rest of the setup
}

############################################
# SUBNET: LOOKUP FOR PLACEMENT OF RESOURCES
############################################
data "azurerm_subnet" "packer_subnet" {
  name                 = "packer-subnet"                                     # Subnet name (must exist inside the VNet above)
  virtual_network_name = data.azurerm_virtual_network.packer_vnet.name       # Reference the parent virtual network
  resource_group_name  = data.azurerm_resource_group.packer_rg.name          # Must match resource group where the subnet resides
}
