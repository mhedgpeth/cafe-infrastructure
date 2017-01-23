variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

variable "computer_name" {}

variable "admin_username" {}

variable "admin_password" {}

variable "chef_user_name" {}

variable "chef_user_key_path" {}

variable "chef_server_url" {}

variable "chef_client_version" {}

variable "ssh_private_key" {}

variable "location" {
  default = "South Central US"
}

variable "stage" {
  default = "test"
}
