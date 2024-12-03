variable "app_config" {
  type = any
  description = "The JSON configuration for the Azure AD SAML application."
}

variable "env" {
    type = string
    description = "Environment of tenant"
}

variable "json_file" {
  type = string
  description = "The name of the JSON file from which the configuration is being passed."
}

variable "app_space" {
  type = string
  description = "The application Json file folder space."
  default = "appspace1"
}

variable "force_trigger" {
    type = bool
    description = "Force trigger powershell"
    default = false
}
