# ==============================================================================
# VIRTUAL NETWORK CONFIGURATION
# ==============================================================================
#
# This section creates the core Azure networking foundation for the project.
# A Virtual Network (VNet) provides an isolated, private IP space where Azure
# resources can communicate securely.
#
# One application subnet (10.0.0.0/25) holds the VMs; the rest of the VNet
# CIDR is left free for growth.
#
# Notes:
# - Keep subnet ranges non-overlapping and sized for future growth.
# - Subnets must be created before NSG associations can be applied.
# ==============================================================================

resource "azurerm_virtual_network" "packer_vnet" {
  # Name of the virtual network (VNet).
  name = "packer-vnet"

  # Address space for the entire VNet (contains all subnets).
  address_space = ["10.0.0.0/23"]

  # Deploy the VNet in the same region as the resource group.
  location = azurerm_resource_group.packer_rg.location

  # Resource group that will own the VNet.
  resource_group_name = azurerm_resource_group.packer_rg.name
}

resource "azurerm_subnet" "packer_subnet" {
  # Subnet for application workloads (VMs, build agents, etc.).
  name = "packer-subnet"

  # Resource group containing the parent VNet.
  resource_group_name = azurerm_resource_group.packer_rg.name

  # Parent virtual network name.
  virtual_network_name = azurerm_virtual_network.packer_vnet.name

  # Address range for the application subnet.
  address_prefixes = ["10.0.0.0/25"]
}

# ==============================================================================
# NETWORK SECURITY GROUP FOR APPLICATION SUBNET
# ==============================================================================
#
# This NSG controls inbound traffic to the application subnet.
# Security rules should be tightened to the minimum required sources and ports.
#
# Notes:
# - Avoid using "*" source ranges in production environments.
# - Prefer restricting SSH/RDP to known IPs.
# - NSG rules are evaluated by priority (lower number = higher precedence).
# ==============================================================================

resource "azurerm_network_security_group" "packer_nsg" {
  # Name of the NSG applied to the application subnet.
  name = "packer-nsg"

  # Deploy the NSG in the same region as the resource group.
  location = azurerm_resource_group.packer_rg.location

  # Resource group that will own this NSG.
  resource_group_name = azurerm_resource_group.packer_rg.name

  security_rule {
    # Allow inbound SSH (tighten source in real deployments).
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    # Allow inbound RDP (only required for Windows workloads).
    name                       = "Allow-RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    # Allow inbound HTTP for web traffic (use HTTPS when possible).
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ==============================================================================
# ASSOCIATE THE NSG TO ITS SUBNET
# ==============================================================================
#
# NSGs do not take effect until they are associated with a subnet (or NIC).
# This binding applies the application NSG to the workload subnet.
#
# Notes:
# - Subnet NSG associations must reference existing subnet and NSG resources.
# - Consider NIC-level NSGs for tighter per-host controls when needed.
# ==============================================================================

resource "azurerm_subnet_network_security_group_association" "packer_nsg_assoc" {
  # Subnet that will receive the application NSG.
  subnet_id = azurerm_subnet.packer_subnet.id

  # NSG that will control traffic for the application subnet.
  network_security_group_id = azurerm_network_security_group.packer_nsg.id
}
