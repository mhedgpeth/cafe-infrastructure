# # Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# Create a resource group
resource "azurerm_resource_group" "cafe" {
  name     = "${var.stage}cafe"
  location = "${var.location}"
}

# Create a virtual network in the cafe resource group
resource "azurerm_virtual_network" "network" {
  name                = "cafeNetwork"
  resource_group_name = "${azurerm_resource_group.cafe.name}"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  subnet {
    name           = "subnet1"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_storage_account" "cafe" {
  name                = "cafestorageacct"
  resource_group_name = "${azurerm_resource_group.cafe.name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "cafe" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.cafe.name}"
  storage_account_name  = "${azurerm_storage_account.cafe.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "cafe" {
  name                   = "cafe.vhd"
  resource_group_name    = "${azurerm_resource_group.cafe.name}"
  storage_account_name   = "${azurerm_storage_account.cafe.name}"
  storage_container_name = "${azurerm_storage_container.cafe.name}"
  type                   = "page"
  size                   = 5120
}

resource "azurerm_public_ip" "cafemaster" {
  name                         = "${var.stage}cafeMasterPublicIp"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.cafe.name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_public_ip" "cafeagent" {
  name                         = "${var.stage}cafeAgentPublicIp"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.cafe.name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_security_group" "cafe" {
  name                = "cafeSecurityGroup"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.cafe.name}"

  security_rule {
    name                       = "cafe"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "cafe" {
  name                = "cafeVirtualNetwork1"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.cafe.name}"
}

resource "azurerm_subnet" "cafe" {
  name                 = "cafesubnet"
  resource_group_name  = "${azurerm_resource_group.cafe.name}"
  virtual_network_name = "${azurerm_virtual_network.cafe.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_network_interface" "cafemaster" {
  name                = "cafeMasterNetworkInterface"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.cafe.name}"

  ip_configuration {
    name                          = "cafeMasterIPconfiguration"
    subnet_id                     = "${azurerm_subnet.cafe.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.cafemaster.id}"
  }
}

resource "azurerm_virtual_machine" "cafemaster" {
  name                  = "${var.stage}cafemaster"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.cafe.name}"
  network_interface_ids = ["${azurerm_network_interface.cafemaster.id}"]
  vm_size               = "Standard_A0"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.2-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.stage}-master-osdisk"
    vhd_uri       = "${azurerm_storage_account.cafe.primary_blob_endpoint}${azurerm_storage_container.cafe.name}/osdiskmaster.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.stage}cafemaster"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  # provisioner "chef" {

  #   node_name       = "${var.stage}cafemaster"

  #   server_url      = "${var.chef_server_url}"

  #   run_list        = []

  #   policy_name     = "jenkins-master"

  #   policy_group    = "qa"

  #   use_policyfile  = true

  #   recreate_client = true

  #   user_name       = "${var.chef_user_name}"

  #   user_key        = "${var.chef_user_key_path}"

  #   version         = "${var.chef_client_version}"

  #   connection {

  #     type        = "ssh"

  #     user        = "${var.admin_username}"

  #     private_key = "${var.ssh_private_key}"

  #     host        = "${azurerm_public_ip.cafemaster.ip_address}"

  #   }

  # }
}

resource "azurerm_network_interface" "cafeagent" {
  name                = "cafeAgentNetworkInterface"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.cafe.name}"

  ip_configuration {
    name                          = "cafeAgentIPconfiguration"
    subnet_id                     = "${azurerm_subnet.cafe.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.cafeagent.id}"
  }
}

resource "azurerm_virtual_machine" "cafeagent" {
  name                  = "${var.stage}cafeagent"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.cafe.name}"
  network_interface_ids = ["${azurerm_network_interface.cafeagent.id}"]
  vm_size               = "Standard_D1"

  storage_image_reference {
    publisher = "microsoftwindowsserver"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-with-Containers"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.stage}-agent-osdisk"
    vhd_uri       = "${azurerm_storage_account.cafe.primary_blob_endpoint}${azurerm_storage_container.cafe.name}/osdiskagent.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.stage}cafeagent"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
}
