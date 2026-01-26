# ==============================================================================
# KEY VAULT SECRETS BOOTSTRAP
# ==============================================================================
#
# This section provisions an Azure Key Vault to act as a centralized secrets
# store for the environment.
#
# A random suffix is appended to the Key Vault name to guarantee uniqueness.
# Key Vault names are globally unique and must be DNS-safe.
#
# The configuration uses Azure RBAC (not legacy access policies) and grants the
# current authenticated principal permission to manage secrets.
#
# Finally, a strong random password is generated and stored as a JSON secret
# payload for downstream automation (e.g., Packer builds).
#
# Notes:
# - Key Vault names must be globally unique across all Azure tenants.
# - RBAC authorization requires role assignments before secrets can be written.
# - Purge protection is disabled here; enable it for production environments.
# - Avoid special characters in generated passwords if tooling is sensitive.
# ==============================================================================

resource "random_string" "key_vault_suffix" {
  # Random lowercase alphanumeric suffix used to ensure DNS-safe uniqueness.
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_key_vault" "packer_key_vault" {
  # Globally unique Key Vault name (DNS-safe).
  name = "packer-kv-${random_string.key_vault_suffix.result}"

  # Place the vault in the project resource group and region.
  resource_group_name = azurerm_resource_group.packer_rg.name
  location            = azurerm_resource_group.packer_rg.location

  # Standard SKU is sufficient for general secrets management.
  sku_name = "standard"

  # Tenant context from the currently authenticated Azure identity.
  tenant_id = data.azurerm_client_config.current.tenant_id

  # Allow irreversible deletion when purge protection is disabled.
  purge_protection_enabled = false

  # Use Azure RBAC authorization model instead of access policies.
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "kv_role_assignment" {
  # Assign the role at the vault scope.
  scope = azurerm_key_vault.packer_key_vault.id

  # Secrets Officer can read/write secrets (not keys/certs).
  role_definition_name = "Key Vault Secrets Officer"

  # Grant access to the currently authenticated user/service principal.
  principal_id = data.azurerm_client_config.current.object_id
}

resource "random_password" "generated" {
  # Strong password for automation workflows.
  length  = 24
  special = false
}

resource "azurerm_key_vault_secret" "packer_secret" {
  # Secret name stored in the Key Vault.
  name = "packer-credentials"

  # Store a JSON payload so consumers can read one secret for multiple fields.
  value = jsonencode({
    username = "packer"
    password = random_password.generated.result
  })

  # Target Key Vault.
  key_vault_id = azurerm_key_vault.packer_key_vault.id

  # Ensure RBAC permissions exist before attempting to write the secret.
  depends_on = [azurerm_role_assignment.kv_role_assignment]

  # Metadata to document the secret payload format.
  content_type = "application/json"
}
