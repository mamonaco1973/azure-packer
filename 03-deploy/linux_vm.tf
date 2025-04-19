# Define a network interface to connect the VM to the network
resource "azurerm_network_interface" "games_nic" {
  name                = "games-nic"                           # Name of the NIC
  location            = data.azurerm_resource_group.packer_rg.location # NIC location matches the resource group
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Links to the resource group

  # IP configuration for the NIC
  ip_configuration {
    name                          = "internal"                     # IP config name
    subnet_id                     = data.azurerm_subnet.packer_subnet.id   # Subnet ID
    private_ip_address_allocation = "Dynamic"                      # Dynamically assign private IP
    public_ip_address_id          = azurerm_public_ip.games_pip.id # Associate with a public IP
  }
}

# Define a public IP for the virtual machine
resource "azurerm_public_ip" "games_pip" {
  name                = "games-pip"                           # Name of the public IP
  location            = data.azurerm_resource_group.packer_rg.location # Public IP location matches the resource group
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Links to the resource group
  allocation_method   = "Static"                              # Dynamically assign public IP
  sku                 = "Standard"                            # Use basic SKU
  domain_name_label   = "games-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}" 
                                                              # Unique domain label for the public IP
}

# Define a Linux virtual machine
resource "azurerm_linux_virtual_machine" "games_vm" {
  name                = "games-vm"                            # Name of the VM
  location            = data.azurerm_resource_group.packer_rg.location # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Links to the resource group
  size                = "Standard_B1s"                        # VM size
  admin_username      = "ubuntu"                              # Admin username for the VM
  
  network_interface_ids = [
    azurerm_network_interface.games_nic.id                      # Associate NIC with the VM
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"                        # Enable read/write caching
    storage_account_type = "Standard_LRS"                     # Standard locally redundant storage
  }

  # Use the custom image from the data block
  source_image_id = data.azurerm_image.games_image.id         # Reference the custom image ID


  # Pass custom data to the VM (e.g., initialization script)
  custom_data = filebase64("scripts/custom_data.sh")
}