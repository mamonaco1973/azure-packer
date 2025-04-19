############################################
# INPUT VARIABLE: CUSTOM IMAGE NAME LINUX
############################################
variable "games_image_name" {
  description = "Name of the custom Azure linux image"   # Human-readable explanation of the variable's purpose
  type        = string                                   # Enforce the input type as a string (required for validation and clarity)
                                                         # This value is typically passed in via CLI, tfvars, or environment
}
############################################
# INPUT VARIABLE: CUSTOM IMAGE NAME WINDOWS
############################################
variable "desktop_image_name" {
  description = "Name of the custom Azure windows image"   # Human-readable explanation of the variable's purpose
  type        = string                                     # Enforce the input type as a string (required for validation and clarity)
                                                           # This value is typically passed in via CLI, tfvars, or environment
}
