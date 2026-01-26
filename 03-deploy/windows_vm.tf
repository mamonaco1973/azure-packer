# ==============================================================================
# INPUT VARIABLES: CUSTOM IMAGE REFERENCES
# ==============================================================================
#
# These variables define the names of pre-existing Azure Managed Images used
# as the source for Linux and Windows virtual machines.
#
# The images are typically produced by Packer builds and stored in a shared
# resource group for reuse across environments.
#
# Notes:
# - Image names must exactly match the managed image names in Azure.
# - Values are commonly supplied via tfvars files or CLI arguments.
# ==============================================================================

variable "games_image_name" {
  # Name of the custom Linux managed image.
  description = "Name of the custom Azure Linux image"
  type        = string
}

variable "desktop_image_name" {
  # Name of the custom Windows managed image.
  description = "Name of the custom Azure Windows image"
  type        = string
}

# ==============================================================================
# INPUT VARIABLES: NETWORK CONTEXT
# ==============================================================================
#
# These variables reference existing network resources used by this module.
# Defaults are provided to match the standard Packer-based lab layout.
#
# Notes:
# - Override defaults when deploying into shared or nonstandard networks.
# - The referenced VNet and subnet must already exist.
# ==============================================================================

variable "vnet_name" {
  # Name of the existing virtual network.
  description = "Name of the existing virtual network"
  type        = string
  default     = "packer-vnet"
}

variable "subnet_name" {
  # Name of the existing subnet.
  description = "Name of the existing subnet"
  type        = string
  default     = "packer-subnet"
}

# ==============================================================================
# INPUT VARIABLE: RESOURCE GROUP CONTEXT
# ==============================================================================
#
# This variable identifies the resource group that owns the custom images and
# network resources consumed by this module.
#
# Notes:
# - The resource group must exist prior to running Terraform.
# - Keeping this configurable improves portability across environments.
# ==============================================================================

variable "resource_group_name" {
  # Name of the existing resource group.
  description = "Name of the existing resource group used for image and network"
  type        = string
  default     = "packer-rg"
}
