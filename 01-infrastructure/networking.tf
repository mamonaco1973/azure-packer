# ==============================================================================
# VIRTUAL NETWORK CONFIGURATION
# ==============================================================================
#
# This section creates the core Azure networking foundation for the project.
# A Virtual Network (VNet) provides an isolated, private IP space where Azure
# resources can communicate securely.
#
# Two subnets are created:
# - An application subnet for workloads such as VMs or build agents.
# - A dedicated Azure Bastion subnet used for browser-based SSH/RDP access.
#
# The VNet CIDR is split into two /25 subnets:
# - 10.0.0.0/25 for application workloads
# - 10.0.1.0/25 for Azure Bastion (AzureBastionSubnet)
#
# Notes:
# - Keep subnet ranges non-overlapping and sized for future growth.
# - The Bastion subnet must be named exactly "AzureBastionSubnet".
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

resource "azurerm_subnet" "bastion_subnet" {
  # Azure Bastion requires this exact subnet name.
  name = "AzureBastionSubnet"

  # Resource group containing the parent VNet.
  resource_group_name = azurerm_resource_group.packer_rg.name

  # Parent virtual network name.
  virtual_network_name = azurerm_virtual_network.packer_vnet.name

  # Address range reserved for Bastion.
  address_prefixes = ["10.0.1.0/25"]
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
# - Prefer restricting SSH/RDP to known IPs or use Bastion instead.
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
# NETWORK SECURITY GROUP FOR BASTION SUBNET
# ==============================================================================
#
# This NSG is tailored for Azure Bastion. Bastion requires HTTPS (443) for the
# user browser session and outbound connectivity to the target VMs via SSH/RDP.
#
# Notes:
# - Azure service tags are used to represent Azure-managed source/dest ranges.
# - Bastion must be able to reach target VMs on ports 22 and/or 3389.
# - Ensure this NSG does not block required Azure control-plane traffic.
# ==============================================================================

resource "azurerm_network_security_group" "bastion_nsg" {
  # Name of the NSG applied to the Bastion subnet.
  name = "bastion-nsg"

  # Deploy the NSG in the same region as the resource group.
  location = azurerm_resource_group.packer_rg.location

  # Resource group that will own this NSG.
  resource_group_name = azurerm_resource_group.packer_rg.name

  security_rule {
    # Allow required inbound HTTPS from Azure GatewayManager service tag.
    name                       = "GatewayManager"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    # Allow inbound HTTPS to Bastion from clients (tighten as needed).
    name                       = "Internet-Bastion-PublicIP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    # Allow Bastion outbound access to VMs for SSH/RDP.
    name                       = "OutboundVirtualNetwork"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    # Allow Bastion outbound HTTPS to Azure control plane.
    name                       = "OutboundToAzureCloud"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

# ==============================================================================
# AZURE BASTION CONFIGURATION
# ==============================================================================
#
# Azure Bastion provides secure, browser-based SSH/RDP access to VMs without
# exposing public IP addresses on the workloads.
#
# A Standard SKU static Public IP is required for Bastion.
#
# Notes:
# - Bastion must be deployed into the "AzureBastionSubnet".
# - Bastion access is over HTTPS (443) from the client browser.
# - Prefer Bastion over opening SSH/RDP to the Internet.
# ==============================================================================

resource "azurerm_public_ip" "bastion_ip" {
  # Public IP address used by the Bastion host.
  name = "bastion-public-ip"

  # Deploy in the same region as the resource group.
  location = azurerm_resource_group.packer_rg.location

  # Resource group that will own this public IP.
  resource_group_name = azurerm_resource_group.packer_rg.name

  # Bastion requires a static public IP address.
  allocation_method = "Static"

  # Bastion requires the Standard SKU public IP.
  sku = "Standard"
}

resource "azurerm_bastion_host" "bastion_host" {
  # Bastion host resource name.
  name = "bastion-host"

  # Deploy in the same region as the resource group.
  location = azurerm_resource_group.packer_rg.location

  # Resource group that will own this Bastion host.
  resource_group_name = azurerm_resource_group.packer_rg.name

  ip_configuration {
    # Internal configuration name for the Bastion host.
    name = "bastion-ip-config"

    # Bastion must be deployed into the AzureBastionSubnet.
    subnet_id = azurerm_subnet.bastion_subnet.id

    # Associate the Bastion host with the static public IP.
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

# ==============================================================================
# ASSOCIATE NSGs TO THEIR SUBNETS
# ==============================================================================
#
# NSGs do not take effect until they are associated with a subnet (or NIC).
# These bindings apply the application NSG to the workload subnet and the
# Bastion NSG to the AzureBastionSubnet.
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

resource "azurerm_subnet_network_security_group_association" "bastion_nsg_assoc" {
  # Subnet that will receive the Bastion NSG.
  subnet_id = azurerm_subnet.bastion_subnet.id

  # NSG that will control traffic for the Bastion subnet.
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}
