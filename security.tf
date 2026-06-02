resource "azurerm_network_security_group" "nsg_dmz" {
  name                = "NSG-DMZ"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_prod" {
  name                = "NSG-Prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-DMZ-to-DB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Association DMZ
resource "azurerm_subnet_network_security_group_association" "assoc_dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.nsg_dmz.id
}

# Association Prod
resource "azurerm_subnet_network_security_group_association" "assoc_prod" {
  subnet_id                 = azurerm_subnet.prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}