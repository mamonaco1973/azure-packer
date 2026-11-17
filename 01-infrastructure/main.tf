# ==============================================================================
# AZURE PROVIDER CONFIGURATION
# ==============================================================================
#
# This provider block configures Terraform to interact with Microsoft Azure
# using Azure Resource Manager (ARM).
#
# Terraform uses the AzureRM provider to authenticate, plan, and apply resource
# changes defined in the configuration.
#
# Notes:
# - The features block is required even if no optional features are enabled.
# - Do not remove the features block or provider initialization will fail.
# - Authentication is typically provided via Azure CLI or a Service Principal.
# ==============================================================================

provider "azurerm" {
  # Required empty block for AzureRM provider initialization.
  features {}
}

# ==============================================================================
# RESOURCE GROUP: PRIMARY CONTAINER FOR PROJECT RESOURCES
# ==============================================================================
#
# This resource group is the top-level container for all project resources.
# Keeping infrastructure in a dedicated RG simplifies lifecycle management,
# cleanup, and cost tracking.
#
# Notes:
# - Resource group names must be unique within the subscription.
# - Choose a region that aligns with latency and compliance requirements.
# ==============================================================================

resource "azurerm_resource_group" "packer_rg" {
  # Logical container for all Azure resources in this project.
  name = "packer-rg"

  # Region where resources will be deployed.
  location = "Central US"
}
