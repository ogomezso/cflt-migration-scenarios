locals {
  resource_group = {
    name     = var.resource_group_name
    location = var.location
  }
}

resource "azurerm_subnet" "test" {
  address_prefixes                               = [var.aks_subnet_cidr]
  name                                           = "cm-clients-aks-sn"
  resource_group_name                            = local.resource_group.name
  virtual_network_name                           = var.vnet_name
}

locals {
  nodes = {
    for i in range(3) : "worker${i}" => {
      name           = substr("worker${i}", 0, 8)
      vm_size        = "Standard_D2s_v3"
      node_count     = 1
      vnet_subnet_id = azurerm_subnet.test.id
    }
  }
}

module "aks" {
  source = "github.com/Azure/terraform-azurerm-aks"

  prefix                        = "cm-clients-aks"
  resource_group_name           = local.resource_group.name
  os_disk_size_gb               = 60
  public_network_access_enabled = false
  sku_tier                      = "Standard"
  rbac_aad                      = false
  vnet_subnet_id                = azurerm_subnet.test.id
  node_pools                    = local.nodes
}