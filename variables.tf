variable "resource_groups" {
  description = "Nested map of resource groups to provision across environments and regions."
  type = map(object({
    location = string
    tags     = map(string)
  }))
  default = {
    "rg-core-hub-prod" = {
      location = "eastus"
      tags = {
        Environment = "Production"
        CostCenter  = "101-Infra"
        ManagedBy   = "Terraform"
      }
    }
    "rg-app-spoke-prod" = {
      location = "eastus"
      tags = {
        Environment = "Production"
        CostCenter  = "202-AppTeam"
        ManagedBy   = "Terraform"
      }
    }
  }
}

variable "vnets_nested_map" {
  description = "Complex nested map of Virtual Networks and their associated Subnets, NSG rules, and Delegation configs."
  type = map(object({
    resource_group_name = string
    address_space       = list(string)
    location            = string
    subnets = map(object({
      address_prefixes  = list(string)
      service_endpoints = optional(list(string), [])
      nsg_rules = optional(map(object({
        priority                   = number
        direction                  = string
        access                     = string
        protocol                   = string
        source_port_range          = string
        destination_port_range     = string
        source_address_prefix      = string
        destination_address_prefix = string
      })), {})
    }))
  }))
  default = {
    "vnet-hub-prod" = {
      resource_group_name = "rg-core-hub-prod"
      address_space       = ["10.100.0.0/16"]
      location            = "eastus"
      subnets = {
        "GatewaySubnet" = {
          address_prefixes  = ["10.100.1.0/24"]
          service_endpoints = []
        }
        "AzureFirewallSubnet" = {
          address_prefixes  = ["10.100.2.0/24"]
          service_endpoints = []
        }
        "snet-management" = {
          address_prefixes  = ["10.100.10.0/24"]
          service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
          nsg_rules = {
            "AllowBastionInbound" = {
              priority                   = 100
              direction                  = "Inbound"
              access                     = "Allow"
              protocol                   = "Tcp"
              source_port_range          = "*"
              destination_port_range     = "443"
              source_address_prefix      = "Internet"
              destination_address_prefix = "*"
            }
          }
        }
      }
    }
    "vnet-spoke-app" = {
      resource_group_name = "rg-app-spoke-prod"
      address_space       = ["10.101.0.0/16"]
      location            = "eastus"
      subnets = {
        "snet-web" = {
          address_prefixes  = ["10.101.1.0/24"]
          service_endpoints = ["Microsoft.Storage"]
          nsg_rules = {
            "AllowHttp" = {
              priority                   = 110
              direction                  = "Inbound"
              access                     = "Allow"
              protocol                   = "Tcp"
              source_port_range          = "*"
              destination_port_range     = "80"
              source_address_prefix      = "10.100.0.0/16"
              destination_address_prefix = "*"
            }
            "AllowHttps" = {
              priority                   = 120
              direction                  = "Inbound"
              access                     = "Allow"
              protocol                   = "Tcp"
              source_port_range          = "*"
              destination_port_range     = "443"
              source_address_prefix      = "10.100.0.0/16"
              destination_address_prefix = "*"
            }
          }
        }
        "snet-db" = {
          address_prefixes  = ["10.101.2.0/24"]
          service_endpoints = ["Microsoft.Sql"]
          nsg_rules = {
            "AllowAppToDb" = {
              priority                   = 130
              direction                  = "Inbound"
              access                     = "Allow"
              protocol                   = "Tcp"
              source_port_range          = "*"
              destination_port_range     = "1433"
              source_address_prefix      = "10.101.1.0/24"
              destination_address_prefix = "*"
            }
          }
        }
      }
    }
  }
}

variable "vms_nested_map" {
  description = "Nested map configuring Linux and Windows VMs with dynamic data disks blocks."
  type = map(object({
    resource_group_name = string
    location            = string
    vm_size             = string
    os_type             = string
    admin_username      = string
    subnet_key          = string
    vnet_key            = string
    data_disks = list(object({
      name                 = string
      disk_size_gb         = number
      lun                  = number
      caching              = string
      storage_account_type = string
    }))
  }))
  default = {
    "vm-web-node01" = {
      resource_group_name = "rg-app-spoke-prod"
      location            = "eastus"
      vm_size             = "Standard_D2s_v5"
      os_type             = "Linux"
      admin_username      = "azureuser"
      vnet_key            = "vnet-spoke-app"
      subnet_key          = "snet-web"
      data_disks = [
        {
          name                 = "disk-data-01"
          disk_size_gb         = 64
          lun                  = 0
          caching              = "ReadWrite"
          storage_account_type = "Premium_LRS"
        },
        {
          name                 = "disk-logs-01"
          disk_size_gb         = 128
          lun                  = 1
          caching              = "ReadOnly"
          storage_account_type = "StandardSSD_LRS"
        }
      ]
    }
  }
}

variable "storage_nestedmap" {
  description = "Nested map for multi-region, multi-tier storage accounts."
  type = map(object({
    name                     = string
    resource_group_name      = string
    location                 = string
    account_tier             = string
    account_replication_type = string
    enable_https_traffic_only = optional(bool, true)
    min_tls_version          = optional(string, "TLS1_2")
  }))
  default = {
    "stgbackup01" = {
      name                     = "stgcorpbackupsdq01"
      resource_group_name      = "rg-core-hub-prod"
      location                 = "eastus"
      account_tier             = "Standard"
      account_replication_type = "GRS"
    }
    "stgapplogs02" = {
      name                     = "stgapplogsdq02"
      resource_group_name      = "rg-app-spoke-prod"
      location                 = "eastus"
      account_tier             = "Premium"
      account_replication_type = "ZRS"
    }
  }
}
