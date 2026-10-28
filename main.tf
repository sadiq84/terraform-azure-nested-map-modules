# 1. Provision Resource Groups from Map
resource "azurerm_resource_group" "rgs" {
  for_each = var.resource_groups

  name     = each.key
  location = each.value.location
  tags     = each.value.tags
}

# 2. Flattening Nested Map of VNets & Subnets
locals {
  # Flatten nested subnets: creates a single map with key "${vnet_key}.${subnet_key}"
  subnets_flattened = merge([
    for vnet_key, vnet_val in var.vnets_nested_map : {
      for snet_key, snet_val in vnet_val.subnets : "${vnet_key}.${snet_key}" => {
        vnet_key          = vnet_key
        subnet_name       = snet_key
        resource_group    = vnet_val.resource_group_name
        address_prefixes  = snet_val.address_prefixes
        service_endpoints = snet_val.service_endpoints
        nsg_rules         = snet_val.nsg_rules
      }
    }
  ]...)

  # Flatten NSG rules across all subnets that define rules
  nsg_rules_flattened = merge([
    for snet_compound_key, snet_data in local.subnets_flattened : {
      for rule_name, rule_data in snet_data.nsg_rules : "${snet_compound_key}.${rule_name}" => merge(rule_data, {
        nsg_key   = snet_compound_key
        rule_name = rule_name
      })
    }
  ]...)
}

# 3. Provision Virtual Networks using for_each
resource "azurerm_virtual_network" "vnets" {
  for_each = var.vnets_nested_map

  name                = each.key
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  address_space       = each.value.address_space

  depends_on = [azurerm_resource_group.rgs]
}

# 4. Provision Subnets from Flattened Nested Map
resource "azurerm_subnet" "subnets" {
  for_each = local.subnets_flattened

  name                 = each.value.subnet_name
  resource_group_name  = each.value.resource_group
  virtual_network_name = azurerm_virtual_network.vnets[each.value.vnet_key].name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
}

# 5. Provision Network Security Groups for Subnets with Rules
resource "azurerm_network_security_group" "nsgs" {
  for_each = {
    for k, v in local.subnets_flattened : k => v
    if length(keys(v.nsg_rules)) > 0
  }

  name                = "nsg-${replace(each.key, ".", "-")}"
  location            = azurerm_virtual_network.vnets[each.value.vnet_key].location
  resource_group_name = each.value.resource_group

  dynamic "security_rule" {
    for_each = each.value.nsg_rules
    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  depends_on = [azurerm_resource_group.rgs]
}

# Associate NSG with Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each = azurerm_network_security_group.nsgs

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = each.value.id
}

# 6. Provision Storage Accounts with Nested Map
resource "azurerm_storage_account" "storage" {
  for_each = var.storage_nestedmap

  name                     = each.value.name
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  account_tier             = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  enable_https_traffic_only = each.value.enable_https_traffic_only
  min_tls_version          = each.value.min_tls_version

  depends_on = [azurerm_resource_group.rgs]
}

# 7. Provision NIC and VM with Dynamic Data Disks
resource "azurerm_network_interface" "nic" {
  for_each = var.vms_nested_map

  name                = "nic-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["${each.value.vnet_key}.${each.value.subnet_key}"].id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_resource_group.rgs]
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = {
    for k, v in var.vms_nested_map : k => v
    if v.os_type == "Linux"
  }

  name                            = each.key
  resource_group_name             = each.value.resource_group_name
  location                        = each.value.location
  size                            = each.value.vm_size
  admin_username                  = each.value.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nic[each.key].id]

  admin_ssh_key {
    username   = each.value.admin_username
    public_key = fileexists("~/.ssh/id_rsa.pub") ? file("~/.ssh/id_rsa.pub") : "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGo4g+M9Fj1+QY5Y5a2QjUvWv0n3l7G8Kq4u2P+EXAMPLE MohammadSadique@Azure"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Managed Disks with Dynamic / For_Each mapping
locals {
  data_disks_flattened = merge([
    for vm_key, vm_val in var.vms_nested_map : {
      for disk in vm_val.data_disks : "${vm_key}.${disk.name}" => merge(disk, {
        vm_key = vm_key
        location = vm_val.location
        resource_group = vm_val.resource_group_name
      })
    }
  ]...)
}

resource "azurerm_managed_disk" "disks" {
  for_each = local.data_disks_flattened

  name                 = each.value.name
  location             = each.value.location
  resource_group_name  = each.value.resource_group
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach" {
  for_each = local.data_disks_flattened

  managed_disk_id    = azurerm_managed_disk.disks[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.value.vm_key].id
  lun                = each.value.lun
  caching            = each.value.caching
}
