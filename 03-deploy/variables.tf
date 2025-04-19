############################################
# INPUT VARIABLE: CUSTOM IMAGE NAME
############################################
variable "games_image_name" {
  description = "The name of the custom Azure image"   # Human-readable explanation of the variable's purpose
  type        = string                                 # Enforce the input type as a string (required for validation and clarity)
                                                       # This value is typically passed in via CLI, tfvars, or environment
}
