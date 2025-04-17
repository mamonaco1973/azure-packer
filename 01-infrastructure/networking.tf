# Define the virtual network
resource "azurerm_virtual_network" "packer-vnet" {
  name                = "packer-vnet"                              # Name of the virtual network
  address_space       = ["10.0.0.0/23"]                               # Address space for the VNet
  location            = azurerm_resource_group.flask-vmss.location    # Azure region
  resource_group_name = azurerm_resource_group.flask-vmss.name        # Resource group for the VNet
}

# Define a subnet within the virtual network
resource "azurerm_subnet" "packer-subnet" {
  name                 = "packer-subnet"                           # Name of the subnet
  resource_group_name  = azurerm_resource_group.flask-vmss.name       # Resource group for the subnet
  virtual_network_name = azurerm_virtual_network.packer-vnet.name  # Parent virtual network name
  address_prefixes     = ["10.0.0.0/25"]                              # Address prefix for the subnet
}

# Define the Azure Bastion subnet
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "AzureBastionSubnet"                         # Required name for Azure Bastion
  resource_group_name  = azurerm_resource_group.flask-vmss.name       # Resource group for the subnet
  virtual_network_name = azurerm_virtual_network.packer-vnet.name  # Parent virtual network name
  address_prefixes     = ["10.0.1.0/25"]                              # Address prefix for the subnet
}

# Define a network security group for the Flask app
resource "azurerm_network_security_group" "packer-nsg" {
  name                = "packer-nsg"                                  # Name of the NSG
  location            = azurerm_resource_group.flask-vmss.location    # Azure region
  resource_group_name = azurerm_resource_group.flask-vmss.name        # Resource group for the NSG

  security_rule {
    name                       = "Allow-SSH"                          # Rule name: Allow SSH
    priority                   = 1000                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "22"                                 # Destination port for SSH
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }

  security_rule {
    name                       = "Allow-RDP"                          # Rule name: Allow RDP
    priority                   = 1001                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "3389"                               # Destination port for RDP
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }

    security_rule {
    name                       = "Allow-HTTP"                         # Rule name: Allow HTTP
    priority                   = 1002                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "80"                                 # Destination port for RDP
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }
}
# Define a network security group for the Azure Bastion
resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "bastion-nsg"                                 # Name of the NSG
  location            = azurerm_resource_group.flask-vmss.location    # Azure region
  resource_group_name = azurerm_resource_group.flask-vmss.name        # Resource group for the NSG

  security_rule {
    name                       = "GatewayManager"                     # Rule name: Gateway Manager
    priority                   = 1001                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "443"                                # Destination port
    source_address_prefix      = "GatewayManager"                     # Source address prefix
    destination_address_prefix = "*"                                  # Destination address prefix
  }

  security_rule {
    name                       = "Internet-Bastion-PublicIP"          # Rule name: Public IP for Bastion
    priority                   = 1002                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "443"                                # Destination port
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }

  security_rule {
    name                       = "OutboundVirtualNetwork"             # Rule name: Outbound to Virtual Network
    priority                   = 1001                                 # Rule priority
    direction                  = "Outbound"                           # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_ranges    = ["22", "3389"]                       # Destination ports for outbound traffic
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "VirtualNetwork"                     # Destination address prefix
  }

  security_rule {
    name                       = "OutboundToAzureCloud"               # Rule name: Outbound to Azure Cloud
    priority                   = 1002                                 # Rule priority
    direction                  = "Outbound"                           # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "443"                                # Destination port
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "AzureCloud"                         # Destination address prefix
  }
}

# Create a Public IP for the Bastion host
resource "azurerm_public_ip" "bastion-ip" {
  name                = "bastion-public-ip"                           # Name of the public IP
  location            = azurerm_resource_group.flask-vmss.location    # Azure region
  resource_group_name = azurerm_resource_group.flask-vmss.name        # Resource group for the public IP
  allocation_method   = "Static"                                      # Allocation method for the public IP
  sku                 = "Standard"                                    # Required for Azure Bastion
}

# Create the Azure Bastion resource
resource "azurerm_bastion_host" "bastion-host" {
  name                = "bastion-host"                                # Name of the Bastion host
  location            = azurerm_resource_group.flask-vmss.location    # Azure region
  resource_group_name = azurerm_resource_group.flask-vmss.name        # Resource group for the Bastion host

  ip_configuration {
    name                 = "bastion-ip-config"                        # Name of the IP configuration
    subnet_id            = azurerm_subnet.bastion-subnet.id           # Subnet for the Bastion host
    public_ip_address_id = azurerm_public_ip.bastion-ip.id            # Public IP associated with the Bastion host
  }
}

# Associate NSG with Flask app subnet
resource "azurerm_subnet_network_security_group_association" "packer-nsg-assoc" {
  subnet_id                 = azurerm_subnet.packer-subnet.id
  network_security_group_id = azurerm_network_security_group.packer-nsg.id
}

# Associate NSG with Application Gateway subnet
resource "azurerm_subnet_network_security_group_association" "app-gateway-nsg-assoc" {
  subnet_id                 = azurerm_subnet.app-gateway-subnet.id
  network_security_group_id = azurerm_network_security_group.packer-gateway.id
}

# Associate NSG with Bastion subnet
resource "azurerm_subnet_network_security_group_association" "bastion-nsg-assoc" {
  subnet_id                 = azurerm_subnet.bastion-subnet.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}
