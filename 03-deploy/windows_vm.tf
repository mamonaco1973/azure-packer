# ==============================================================================
# WINDOWS VM NETWORKING AND DEPLOYMENT
# ==============================================================================
#
# This module provisions a public-facing Windows VM backed by a custom Azure
# Managed Image. The deployment includes:
# - A Standard SKU static Public IP with a predictable DNS label
# - A Network Interface (NIC) attached to the target subnet
# - A Windows VM with a generated local admin password
# - Optional custom_data bootstrap rendered from a PowerShell template
# - A Custom Script Extension to execute the custom_data payload at runtime
#
# Notes:
# - Public RDP should be restricted or replaced with Azure Bastion.
# - Standard SKU public IPs are recommended for production deployments.
# - custom_data is base64-encoded and size-limited by Azure.
# - The extension is used because Windows custom_data is not always executed
#   automatically as a PowerShell script without additional handling.
# ==============================================================================

resource "azurerm_public_ip" "desktop_pip" {
  # Public IP resource used for external access to the VM.
  name = "desktop-pip"

  # Deploy the public IP into the same resource group and region.
  location            = data.azurerm_resource_group.packer_rg.location
  resource_group_name = data.azurerm_resource_group.packer_rg.name

  # Static allocation keeps the IP stable across VM reboots.
  allocation_method = "Static"

  # Standard SKU provides better resiliency and feature support.
  sku = "Standard"

  # Globally unique DNS label derived from the subscription ID prefix.
  domain_name_label = "desktop-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
}

resource "azurerm_network_interface" "desktop_nic" {
  # NIC attached to the VM and connected to the application subnet.
  name = "desktop-nic"

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
    public_ip_address_id = azurerm_public_ip.desktop_pip.id
  }
}

# ==============================================================================
# RANDOM PASSWORD: WINDOWS LOCAL ADMIN CREDENTIAL
# ==============================================================================
#
# Generate a strong password for the local Windows administrator account.
# This supports automated provisioning without hardcoding credentials.
#
# Notes:
# - Avoid special characters to reduce quoting/escaping issues in automation.
# - Store the result securely (Key Vault, pipeline secret store, etc.).
# ==============================================================================

resource "random_password" "windows" {
  length  = 24
  special = false
}

# ==============================================================================
# WINDOWS VIRTUAL MACHINE: CUSTOM IMAGE DEPLOYMENT
# ==============================================================================
#
# This VM is created from a custom managed image (typically built by Packer).
# A PowerShell bootstrap script is rendered and passed via custom_data.
#
# Notes:
# - provision_vm_agent must be enabled for extensions to run.
# - Consider using Azure Bastion instead of exposing RDP publicly.
# ==============================================================================

resource "azurerm_windows_virtual_machine" "desktop_vm" {
  # Name of the VM shown in the Azure portal.
  name = "desktop-vm"

  # Deploy the VM into the same resource group and region.
  location            = data.azurerm_resource_group.packer_rg.location
  resource_group_name = data.azurerm_resource_group.packer_rg.name

  # VM size selected for light desktop workloads.
  size = "Standard_B2s"

  # Local administrator credentials.
  admin_username = "azureadmin"
  admin_password = random_password.windows.result

  # Required for extensions and guest configuration.
  provision_vm_agent = true

  # Attach the NIC created above.
  network_interface_ids = [
    azurerm_network_interface.desktop_nic.id
  ]

  os_disk {
    # Basic OS disk settings for cost-effective storage.
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Custom managed image used as the VM source.
  source_image_id = data.azurerm_image.desktop_image.id
}

# ==============================================================================
# OUTPUTS
# ==============================================================================
#
# Expose the public FQDN so clients can connect without manually locating the
# DNS name after deployment.
# ==============================================================================

output "desktop_vm_fqdn" {
  description = "FQDN of the public IP assigned to the desktop VM"
  value       = azurerm_public_ip.desktop_pip.fqdn
}
