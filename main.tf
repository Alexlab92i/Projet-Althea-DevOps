# --- CONFIGURATION DU PROVIDER (Tâche 1) ---
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# --- GROUPE DE RESSOURCES (Tâche 2) ---
resource "azurerm_resource_group" "rg" {
  name     = "RG-Althea-Systems"
  location = "swedencentral"
}

# --- LE VNET ET LES SUBNETS (Tâche 3) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "VNet-Althea"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 1. Subnet-Prod (Comptabilité & Données)
resource "azurerm_subnet" "prod" {
  name                 = "Subnet-Prod"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 2. Subnet-DMZ (Site Web Public)
resource "azurerm_subnet" "dmz" {
  name                 = "Subnet-DMZ"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3. Subnet-Admin (Gestion & Bastion)
resource "azurerm_subnet" "admin" {
  name                 = "Subnet-Admin"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# --- IP PUBLIQUE TEMPORAIRE POUR ANSIBLE ---
resource "azurerm_public_ip" "pip_compta" {
  name                = "pip-compta"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- LA MACHINE VIRTUELLE COMPTABILITÉ ---
resource "azurerm_network_interface" "nic_prod" {
  name                = "nic-compta"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prod.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_compta.id
  }
}

resource "azurerm_linux_virtual_machine" "vm_compta" {
  name                            = "VM-Compta"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s_v2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rdAlthea2026!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nic_prod.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# --- LES 2 VMs SITE WEB (DMZ) ---

# NIC VM Web 1
resource "azurerm_network_interface" "nic_web1" {
  name                = "nic-web1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Dynamic"
  }
}

# NIC VM Web 2
resource "azurerm_network_interface" "nic_web2" {
  name                = "nic-web2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Dynamic"
  }
}

# VM Web 1
resource "azurerm_linux_virtual_machine" "vm_web1" {
  name                            = "VM-Web1"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2ats_v2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rdAlthea2026!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nic_web1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# VM Web 2
resource "azurerm_linux_virtual_machine" "vm_web2" {
  name                            = "VM-Web2"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2als_v2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rdAlthea2026!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nic_web2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# --- LOAD BALANCER ---

# IP publique du Load Balancer
resource "azurerm_public_ip" "pip_lb" {
  name                = "pip-loadbalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "LB-Althea"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }
}

# Pool de machines derrière le Load Balancer
resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Rattacher VM-Web1 au pool
resource "azurerm_network_interface_backend_address_pool_association" "assoc_web1" {
  network_interface_id    = azurerm_network_interface.nic_web1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

# Rattacher VM-Web2 au pool
resource "azurerm_network_interface_backend_address_pool_association" "assoc_web2" {
  network_interface_id    = azurerm_network_interface.nic_web2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

# Règle : le LB envoie le trafic HTTPS vers les VMs Web
resource "azurerm_lb_rule" "rule_https" {
  name                           = "rule-https"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
}

# Sonde de santé : vérifie que les VMs répondent
resource "azurerm_lb_probe" "probe" {
  name            = "probe-https"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 443
}