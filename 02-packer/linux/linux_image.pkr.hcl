# ==============================================================================
# PACKER TEMPLATE: AZURE IMAGE BUILD CONFIGURATION
# ==============================================================================
#
# This file defines a Packer build that creates a reusable Azure Managed Image.
# The template is composed of:
# - Packer plugin configuration (Azure ARM builder plugin)
# - A timestamp local used to generate unique image names
# - Input variables for Azure authentication and build parameters
# - A source block describing the base image and build VM settings
# - A build block that provisions the image (copy files + run scripts)
#
# Notes:
# - Azure authentication is typically provided via a Service Principal.
# - Do not hardcode secrets in templates; prefer env vars or CI secret stores.
# - Managed image names must be unique within the target resource group.
# - Keep provisioning scripts idempotent where possible for repeatable builds.
# ==============================================================================

packer {
  required_plugins {
    azure = {
      # Official HashiCorp Azure plugin for Packer.
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

locals {
  # Compact timestamp used to make managed image names unique.
  # Example: YYYYMMDDHHMMSS
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# ==============================================================================
# REQUIRED VARIABLES: AZURE AUTHENTICATION AND BUILD PARAMETERS
# ==============================================================================
#
# These variables define the Azure authentication context and build targets.
# Most workflows use an Azure AD App Registration (Service Principal).
#
# Notes:
# - Supply secrets via environment variables or a CI/CD secret store.
# - Avoid committing credentials into source control.
# ==============================================================================

variable "client_id" {
  # Azure AD application (service principal) client ID.
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  # Azure AD application (service principal) client secret.
  description = "Azure Client Secret"
  type        = string
}

variable "subscription_id" {
  # Azure subscription where the build VM runs and the image is created.
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  # Azure AD tenant (directory) that owns the service principal.
  description = "Azure Tenant ID"
  type        = string
}

variable "password" {
  # Optional password passed to provisioning scripts via environment variable.
  # Prefer SSH keys; only enable password auth when required by the workflow.
  description = "The password for the packer account"
  type        = string
  default     = ""
}

variable "resource_group" {
  # Resource group where the final managed image will be stored.
  description = "Resource group where the VM image will be created"
  type        = string
}

# ==============================================================================
# SOURCE BLOCK: AZURE MANAGED IMAGE BUILDER
# ==============================================================================
#
# The azure-arm builder creates a temporary VM from a Marketplace base image,
# runs provisioners against it, then captures it into an Azure Managed Image.
#
# Notes:
# - The base image here is Ubuntu 24.04 LTS from Canonical.
# - Choose an appropriately sized VM for build speed vs. cost.
# - The managed image is written to the resource group provided by var.
# ==============================================================================

source "azure-arm" "games_image" {
  # Azure authentication (Service Principal / App Registration).
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Marketplace base image selection (Ubuntu 24.04 LTS).
  image_offer     = "ubuntu-24_04-lts"
  image_publisher = "canonical"
  image_sku       = "server"

  # SSH user for provisioning steps.
  ssh_username = "ubuntu"

  # Build VM region, size, and OS type.
  location = "Central US"
  vm_size  = "Standard_B1s"
  os_type  = "Linux"

  # Optional disk tuning (uncomment if you need larger/faster disks).
  # os_disk_size_gb           = 64
  # os_disk_managed_disk_type = "Premium_LRS"

  # Output managed image settings.
  managed_image_name                 = "games_image_${local.timestamp}"
  managed_image_resource_group_name  = var.resource_group
}

# ==============================================================================
# BUILD BLOCK: PROVISIONING WORKFLOW
# ==============================================================================
#
# This build performs a simple provisioning sequence:
# 1) Create a temporary working directory on the VM
# 2) Copy static assets into the VM
# 3) Run an installation script (packages, services, configuration)
# 4) Apply SSH configuration changes (optionally enabling password auth)
#
# Notes:
# - Keep scripts idempotent so rebuilds behave predictably.
# - Prefer passing secrets via environment vars, never hardcoded strings.
# - Validate scripts locally (shellcheck) before running Packer builds.
# ==============================================================================

build {
  # Bind this build to the Azure source defined above.
  sources = ["source.azure-arm.games_image"]

  provisioner "shell" {
    # Ensure destination path exists before copying files.
    inline = ["mkdir -p /tmp/html"]
  }

  provisioner "file" {
    # Copy local static assets into the VM for installation/config.
    source      = "./html/"
    destination = "/tmp/html/"
  }

  provisioner "shell" {
    # Install packages and configure services required by the image.
    script = "./install.sh"
  }

  provisioner "shell" {
    # Configure SSH behavior (e.g., password auth) when required.
    script = "./config_ssh.sh"

    # Pass secrets to scripts via environment vars (not inline values).
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"
    ]
  }
}
