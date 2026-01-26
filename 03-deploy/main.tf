# ==============================================================================
# AZURE CONTEXT: PROVIDER AND DATA SOURCES
# ==============================================================================
#
# This section configures the AzureRM provider and loads the Azure context
# needed by downstream resources.
#
# The data sources are used to:
# - Discover the active subscription and authenticated client identity
# - Look up an existing resource group (instead of creating a new one)
# - Locate previously built custom images (e.g., Packer-managed images)
# - Retrieve existing network resources (VNet and subnet) for placement
#
# Notes:
# - The provider features block is required boilerplate for AzureRM.
# - Using data sources keeps this module reusable across environments.
# - Image lookups assume the images already exist in the target resource group.
# ==============================================================================

provider "azurerm" {
  # Required empty block for AzureRM provider initialization.
  features {}
}

data "azurerm_subscription" "primary" {
  # Active subscription context (ID, display name, tenant linkage).
}

data "azurerm_client_config" "current" {
  # Authenticated client context (tenant_id, object_id, subscription_id).
}

# ==============================================================================
# RESOURCE GROUP LOOKUP
# ==============================================================================
#
# This module targets an existing resource group provided as input.
# Keeping the RG external allows consistent naming and lifecycle control.
# ==============================================================================

data "azurerm_resource_group" "packer_rg" {
  # Existing resource group used for image, network, and VM resources.
  name = var.resource_group_name
}

# ==============================================================================
# CUSTOM IMAGE LOOKUPS
# ==============================================================================
#
# These data sources resolve custom managed images that were created earlier.
# The images are referenced by name and must exist in the target resource group.
#
# Notes:
# - Managed images are commonly produced by Packer builds.
# - If images are stored in a Shared Image Gallery, use the SIG data sources.
# ==============================================================================

data "azurerm_image" "games_image" {
  # Custom Linux image used for the games VM deployment.
  name                = var.games_image_name
  resource_group_name = data.azurerm_resource_group.packer_rg.name
}

data "azurerm_image" "desktop_image" {
  # Custom Windows image used for the desktop VM deployment.
  name                = var.desktop_image_name
  resource_group_name = data.azurerm_resource_group.packer_rg.name
}

# ==============================================================================
# NETWORK LOOKUPS: VNET AND SUBNET CONTEXT
# ==============================================================================
#
# These lookups retrieve the existing VNet and subnet used to attach NICs and
# place VMs into the correct address space.
#
# Notes:
# - VNet and subnet names are passed in to keep the module environment-agnostic.
# - Ensure the subnet has sufficient IP capacity for the planned deployments.
# ==============================================================================

data "azurerm_virtual_network" "packer_vnet" {
  # Existing VNet used for workload placement.
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.packer_rg.name
}

data "azurerm_subnet" "packer_subnet" {
  # Existing subnet used for VM NIC attachment.
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.packer_vnet.name
  resource_group_name  = data.azurerm_resource_group.packer_rg.name
}
