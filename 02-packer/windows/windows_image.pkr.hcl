# ==============================================================================
# PACKER TEMPLATE: AZURE WINDOWS SERVER IMAGE BUILD
# ==============================================================================
#
# This template builds a reusable Azure Managed Image based on Windows Server
# 2022 Datacenter. The build uses WinRM for provisioning and applies updates,
# security hardening, and desktop tooling configuration before sysprepping.
#
# The template is composed of:
# - Packer plugin configuration (Azure + Windows Update)
# - A timestamp local used to generate unique image names
# - Input variables for Azure authentication and build parameters
# - A source block describing the base image and WinRM communicator settings
# - A build block that provisions, reboots, and generalizes the VM
#
# Notes:
# - Provide Azure credentials via a Service Principal (client_id/secret).
# - Do not hardcode secrets; pass passwords via env vars or CI secret stores.
# - WinRM uses SSL here with insecure validation for simplicity.
# - Sysprep must run at the end to generalize the image for reuse.
# ==============================================================================

packer {
  required_plugins {
    azure = {
      # Official HashiCorp Azure builder plugin for Packer.
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }

    windows-update = {
      # Provisioner plugin used to apply Windows Updates during builds.
      source  = "github.com/rgl/windows-update"
      version = "0.15.0"
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
# These variables define the Azure authentication context and the destination
# resource group where the resulting managed image will be stored.
#
# Notes:
# - Supply secrets via environment variables or a CI/CD secret store.
# - Avoid committing client secrets or administrator passwords to source control.
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

variable "resource_group" {
  # Resource group where the final managed image will be stored.
  description = "Resource group where the VM image will be created"
  type        = string
}

variable "password" {
  # Administrator password used for WinRM during the build.
  # Provide this securely via env vars or CI/CD secret management.
  description = "Administrator password for WinRM access"
  type        = string
  default     = ""
}

# ==============================================================================
# SOURCE BLOCK: AZURE WINDOWS SERVER BUILDER
# ==============================================================================
#
# The azure-arm builder creates a temporary Windows VM from a Marketplace base
# image, runs provisioners over WinRM, then captures a generalized managed image.
#
# Notes:
# - Windows Server 2022 Datacenter is used as the base Marketplace image.
# - VM size impacts build speed and cost; choose based on workload needs.
# - WinRM is configured with SSL; certificate validation is disabled here.
# ==============================================================================

source "azure-arm" "desktop_image" {
  # Azure authentication (Service Principal / App Registration).
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  # Marketplace base image selection (Windows Server 2022 Datacenter).
  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-Datacenter"

  # Build VM region and size.
  location = "Central US"
  vm_size  = "Standard_D2s_v3"

  # Output managed image settings.
  managed_image_name                = "desktop_image_${local.timestamp}"
  managed_image_resource_group_name = var.resource_group

  # WinRM communicator configuration for Windows provisioning.
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_username = "builder"
  winrm_password = var.password
}

# ==============================================================================
# BUILD BLOCK: WINDOWS PATCHING, CONFIGURATION, AND SYSPREP
# ==============================================================================
#
# This build provisions the temporary Windows VM in a predictable sequence:
# 1) Apply Windows Updates
# 2) Reboot if required after patching
# 3) Run security hardening and user configuration
# 4) Create an artifact directory for postbuild scripts/files
# 5) Upload boot-time configuration scripts
# 6) Install desktop tooling (Chrome, Firefox) and configure desktop icons
# 7) Run Sysprep to generalize and shut down the VM for image capture
#
# Notes:
# - Reboots are normal after updates; keep restart timeouts generous.
# - Ensure scripts are idempotent and safe to re-run during rebuilds.
# - Sysprep should be the final step to avoid breaking WinRM provisioning.
# ==============================================================================

build {
  # Bind this build to the Azure source defined above.
  sources = ["source.azure-arm.desktop_image"]

  provisioner "windows-update" {
    # Apply available Windows updates during the image build.
  }

  provisioner "windows-restart" {
    # Reboot to complete post-update installation when required.
    restart_timeout = "15m"
  }

  provisioner "powershell" {
    # Apply security hardening and configure local users/settings.
    script = "./security.ps1"

    # Pass secrets to scripts via environment vars (not inline values).
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"
    ]
  }

  provisioner "powershell" {
    # Create a working directory for build artifacts and scripts.
    inline = [
      "mkdir C:\\mcloud"
    ]
  }

  provisioner "file" {
    # Upload boot-time configuration script to the VM.
    source      = "./boot.ps1"
    destination = "C:\\mcloud\\"
  }

  provisioner "powershell" {
    # Install Google Chrome.
    script = "./chrome.ps1"
  }

  provisioner "powershell" {
    # Install Mozilla Firefox.
    script = "./firefox.ps1"
  }

  provisioner "powershell" {
    # Configure desktop shortcuts and icons.
    script = "./desktop.ps1"
  }

  provisioner "powershell" {
    # Generalize the VM so the resulting image is reusable.
    inline = [
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet"
    ]
  }
}
