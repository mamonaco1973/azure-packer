############################################
# PACKER CONFIGURATION AND PLUGIN SETUP
############################################

packer {
  required_plugins {
    azure = {
      source   = "github.com/hashicorp/azure"
      version  = "~> 2"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}


variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}


variable "password" {
  description = "The password for the packer account"    # Will be passed into SSH provisioning script
  default     = ""                                       # Must be overridden securely via env or CLI
}


############################################
# AMAZON-EBS SOURCE BLOCK: BUILD CUSTOM UBUNTU IMAGE
############################################

source "azure-arm"  "games_image" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  image_offer                       = "ubuntu-24_04-lts"
  image_publisher                   = "canonical"
  image_sku                         = "server"
  location                          = "Central US"
  vm_size                           = "Standard_B1s"
  os_type                           = "Linux"

  managed_image_name                = "games_image_${local.timestamp}"
  managed_image_resource_group_name = "packer-rg"
}

############################################
# BUILD BLOCK: PROVISION FILES AND RUN SETUP SCRIPTS
############################################

build {

  sources = ["source.azure-armg.games_image"]

  # Create a temp directory for HTML files
  provisioner "shell" {
    inline = ["mkdir -p /tmp/html"]                      # Ensure target directory exists on VM
  }

  # Copy local HTML files to the instance
  provisioner "file" {
    source      = "./html/"                              # Source directory from local machine
    destination = "/tmp/html/"                           # Target directory inside VM
  }

  # Run install script inside the instance
  provisioner "shell" {
    script = "./install.sh"                              # Installs and configures required packages
  }

  # Run SSH configuration script, passing in a password variable
  provisioner "shell" {
    script = "./config_ssh.sh"                           # Custom script to enable SSH password login
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"                  # Export password to the script environment
    ]
  }
}
