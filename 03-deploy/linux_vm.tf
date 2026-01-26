# ==============================================================================
# LINUX VM NETWORKING AND DEPLOYMENT
# ==============================================================================
#
# This section provisions a public-facing Linux VM backed by a custom Azure
# Managed Image. The deployment includes:
# - A Standard SKU static Public IP with a predictable DNS label
# - A Network Interface (NIC) bound to the application subnet
# - A Linux VM configured for password authentication (for convenience)
# - Custom cloud-init style bootstrap via custom_data
#
# Notes:
# - Standard SKU public IPs are recommended for production deployments.
# - Public SSH access should be restricted or replaced with Azure Bastion.
# - Password authentication is enabled here; prefer SSH keys in production.
# - The DNS label must be globally unique within the Azure region.
# ==============================================================================

resource "azurerm_public_ip" "games_pip" {
  # Public IP resource for external access to the VM.
  name = "games-pip"

  # Deploy the public IP into the same resource group and region.
  location            = data.azurerm_resource_group.packer_rg.location
  resource_group_name = data.azurerm_resource_group.packer_rg.name

  # Static allocation keeps the IP stable across VM reboots.
  allocation_method = "Static"

  # Standard SKU provides better resiliency and feature support.
  sku = "Standard"

  # Globally unique DNS label derived from the subscription ID prefix.
  domain_name_label = "games-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
}

resource "azurerm_network_interface" "games_nic" {
  # NIC attached to the VM and connected to the application subnet.
  name = "games-nic"

  # Deploy the NIC into the same resource group and region.
  location            = data.azurerm_resource_group.packer_rg.location
  resource_group_name = data.azurerm_resource_group.packer_rg.name

  ip_configuration {
    # Primary NIC IP configuration.
    name = "internal"

    # Attach the NIC to the target subnet.
    subnet_id = data.azurerm_subnet.packer_subnet.id

    # Let Azure allocate the private IP dynamically.
    private_ip_address_allocation = "Dynamic"

    # Bind the static public IP for inbound connectivity.
    public_ip_address_id = azurerm_public_ip.games_pip.id
  }
}

# ==============================================================================
# RANDOM PASSWORD: LINUX ADMIN CREDENTIAL
# ==============================================================================
#
# This password is used for the VM admin user when password authentication is
# enabled. Password auth is convenient for demos, but SSH keys are preferred.
#
# Notes:
# - If password auth is disabled, remove admin_password and use SSH keys.
# - Ensure password values are never logged or committed to source control.
# ==============================================================================

resource "random_password" "ubuntu" {
  # Strong random password used for the VM admin account.
  length  = 24
  special = true
}

# ==============================================================================
# LINUX VIRTUAL MACHINE: CUSTOM IMAGE DEPLOYMENT
# ==============================================================================
#
# This VM is created from a custom managed image (built by Packer or sourced
# from an image gallery). The VM boots with custom_data to run first-boot
# configuration (cloud-init style) via a rendered shell script template.
#
# Notes:
# - Password authentication is enabled here for convenience.
# - Prefer restricting SSH inbound rules or using Bastion for access.
# - custom_data must be base64-encoded and is limited in size by Azure.
# ==============================================================================

resource "azurerm_linux_virtual_machine" "games_vm" {
  # Name of the VM shown in the Azure portal.
  name = "games-vm"

  # Deploy the VM into the same resource group and region.
  location            = data.azurerm_resource_group.packer_rg.location
  resource_group_name = data.azurerm_resource_group.packer_rg.name

  # VM size selected for low-cost, lightweight workloads.
  size = "Standard_B1s"

  # Local admin account used for initial access.
  admin_username = "ubuntu"
  admin_password = random_password.ubuntu.result

  # Enable password auth (set true to force SSH-only).
  disable_password_authentication = false

  # Attach the NIC created above.
  network_interface_ids = [
    azurerm_network_interface.games_nic.id
  ]

  os_disk {
    # Basic OS disk settings for cost-effective storage.
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Custom image used as the VM source.
  source_image_id = data.azurerm_image.games_image.id

  # Bootstrap script rendered from template and passed as base64.
  custom_data = base64encode(templatefile("${path.module}/scripts/custom_data.sh", {
    image = data.azurerm_image.games_image.name
  }))
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
#
# Expose the public FQDN so clients can connect without manually locating the
# assigned DNS name after deployment.
# ==============================================================================

output "games_vm_fqdn" {
  description = "FQDN of the public IP assigned to the games VM"
  value       = azurerm_public_ip.games_pip.fqdn
}
