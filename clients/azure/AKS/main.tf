locals {
  resource_group = {
    name     = var.resource_group_name
    location = var.location
  }
}

resource "azurerm_subnet" "test" {
  address_prefixes     = [var.aks_subnet_cidr]
  name                 = "cm-clients-aks-sn"
  resource_group_name  = local.resource_group.name
  virtual_network_name = var.vnet_name
}

module "aks" {
  source = "github.com/Azure/terraform-azurerm-aks"

  prefix                          = "cm-clients"
  resource_group_name             = local.resource_group.name
  os_disk_size_gb                 = 60
  public_network_access_enabled   = true
  api_server_authorized_ip_ranges = ["0.0.0.0/32"]
  sku_tier                        = "Standard"
  rbac_aad                        = false
  vnet_subnet_id                  = azurerm_subnet.test.id
}
