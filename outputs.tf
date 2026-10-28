output "resource_group_ids" {
  description = "Map of all provisioned Resource Group IDs."
  value       = { for k, v in azurerm_resource_group.rgs : k => v.id }
}

output "vnet_ids" {
  description = "Map of all provisioned Virtual Network IDs."
  value       = { for k, v in azurerm_virtual_network.vnets : k => v.id }
}

output "subnet_ids" {
  description = "Compound map of all provisioned Subnet IDs (vnet_key.subnet_name)."
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "nsg_ids" {
  description = "Map of Network Security Group IDs created dynamically."
  value       = { for k, v in azurerm_network_security_group.nsgs : k => v.id }
}

output "storage_account_endpoints" {
  description = "Primary endpoints of all provisioned storage accounts."
  value = {
    for k, v in azurerm_storage_account.storage : k => {
      id          = v.id
      primary_blob = v.primary_blob_endpoint
    }
  }
}

output "vm_private_ips" {
  description = "Private IP addresses assigned to the virtual machine NICs."
  value = {
    for k, v in azurerm_network_interface.nic : k => v.private_ip_address
  }
}
