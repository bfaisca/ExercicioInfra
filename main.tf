terraform{
    required_version = " >= 0.13"
 
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    }
}

provider "azurerm" {
    features{}
}

resource "azurerm_resource_group" "rg-exercicioInfra" {
  name     = "exercicioInfraCloundTerra"
  location = "centralus"
}

resource "azurerm_virtual_network" "vnet-exercicioInfra" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-exercicioInfra.location
  resource_group_name = azurerm_resource_group.rg-exercicioInfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    turma = "TFS-04"
    faculdade = "Impacta"
    aluno = "Brendo"
    professor = "Joao"
  }
}

resource "azurerm_subnet" "subExercicioInfra" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-exercicioInfra.name
  virtual_network_name = azurerm_virtual_network.vnet-exercicioInfra.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ipExercicioInfra" {
  name                    = "publicIp"
  location                = azurerm_resource_group.rg-exercicioInfra.location
  resource_group_name     = azurerm_resource_group.rg-exercicioInfra.name
  allocation_method       = "Static"
}

resource "azurerm_network_security_group" "nsgExercicioInfra" {
  name                = "nsg"
  location            = azurerm_resource_group.rg-exercicioInfra.location
  resource_group_name = azurerm_resource_group.rg-exercicioInfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
  faculdade = "Impacta"
  }
}

resource "azurerm_network_interface" "nicExercicioInfra" {
  name                = "nic"
  location            = azurerm_resource_group.rg-exercicioInfra.location
  resource_group_name = azurerm_resource_group.rg-exercicioInfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.subExercicioInfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ipExercicioInfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-ExercicioInfra" {
  network_interface_id      = azurerm_network_interface.nicExercicioInfra.id
  network_security_group_id = azurerm_network_security_group.nsgExercicioInfra.id
}

resource "azurerm_storage_account" "saExercicioInfra" {
  name                     = "saexercicioinfra"
  resource_group_name      = azurerm_resource_group.rg-exercicioInfra.name
  location                 = azurerm_resource_group.rg-exercicioInfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
   faculdade = "Impacta"
  }
}

resource "azurerm_linux_virtual_machine" "vmExercicioInfra" {
  name                = "myvm"
  resource_group_name = azurerm_resource_group.rg-exercicioInfra.name
  location            = azurerm_resource_group.rg-exercicioInfra.location
  size                = "Standard_D2ads_v5"

  network_interface_ids = [
    azurerm_network_interface.nicExercicioInfra.id
  ]

    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "mydisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.saExercicioInfra.primary_blob_endpoint
  }

}

data "azurerm_public_ip" "ipexercicioInfradata"{
  name = azurerm_public_ip.ipExercicioInfra.name
  resource_group_name = azurerm_resource_group.rg-exercicioInfra.name
}

variable "user" {
  description = "usuário da maquina"
  type= string 
}

variable "password"{
 description = "senha da maquina"
  type= string 
}

resource "null_resource" "install-webserver" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ipexercicioInfradata.ip_address
    user = var.user
    password= var.password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vmExercicioInfra
  ]
  
}