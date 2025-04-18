resource "random_string" "key_vault_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create an Azure Key Vault
resource "azurerm_key_vault" "packer_key_vault" {
  name                        = "packer-kv-${random_string.key_vault_suffix.result}"  
  resource_group_name         = azurerm_resource_group.packer_rg.name
  location                    = azurerm_resource_group.packer_rg.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
}

# Assign RBAC role to the current client for managing secrets
resource "azurerm_role_assignment" "kv_role_assignment" {
  scope                = azurerm_key_vault.packer_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --- User: Packer ---

# Generate a secure random alphanumeric password
resource "random_password" "generated" {
  length  = 24         # Total password length: 24 characters
  special = false      # Exclude special characters (alphanumeric only for compatibility)
}


# Create secret for "packer" credentials

resource "azurerm_key_vault_secret" "packer_secret" {
  name         = "packer-credentials"
  value        = jsonencode({
    username = "packer"
    password = random_password.generated.result
  })
  key_vault_id = azurerm_key_vault.packer_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}
