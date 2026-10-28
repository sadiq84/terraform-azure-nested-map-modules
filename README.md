<div align="center">

# ⚡ Terraform Azure Advanced Nested Maps & For-Each Architecture
### Production-Grade Enterprise Infrastructure as Code (IaC) Framework

[![Terraform](https://img.shields.io/badge/Terraform->=_1.5.0-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Microsoft_Azure-Provider_~>_3.90-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](#)
[![Architect](https://img.shields.io/badge/Author-Mohammad_Sadique_Qutub-06B6D4?style=for-the-badge)](#)

<br/>

```
  ========================================================================================
  [ ARCHITECTURAL PATTERN: ADVANCED NESTED MAPS & DYNAMIC BLOCKS ]
  * Complex Data Schema: map(object({ subnets = map(object({ nsg_rules = map(...) })) }))
  * High-Performance flatten() Logic for Deterministic State Key Generation
  * Dynamic Blocks for Security Rules and Multi-Disk Attachments
  ========================================================================================
```

</div>

---

## 📌 Executive Overview

This repository demonstrates **enterprise-grade Terraform architecture** for provisioning complex, multi-tier Azure landing zones and workload infrastructure using **nested map data structures**, `for_each` meta-arguments, and `flatten()` transformations.

In standard enterprise production environments, hard-coding separate resources or using simple lists leads to state churn, configuration drift, and rigid index-based deployments. By leveraging strongly typed `map(object({...}))` contracts, this module provides:

1. **Non-Destructive State Mutations**: Changing or removing a subnet or VM in the map does not trigger re-indexing or recreation of sibling resources.
2. **Compound Key Transformation**: Leverages nested `merge()` and `flatten()` projections to construct deterministic compound state keys (`vnet_name.subnet_name`).
3. **Dynamic Block Interpolation**: Generates inline NSG security rules and virtual machine data disk attachments on demand without code duplication.

---

## 🏗️ Architecture Schema & Flow

```
                      [ Complex Nested Map Configuration ]
                                       |
                   var.vnets_nested_map & var.vms_nested_map
                                       |
         +-----------------------------+-----------------------------+
         |                                                           |
         v                                                           v
[ Virtual Networks Layer ]                                  [ Flattened Subnets Map ]
- for_each = var.vnets_nested_map                           - merge([ for vnet in vnets : ... ])
- Non-overlapping CIDR spaces                               - Compound Keys: "${vnet}.${snet}"
         |                                                           |
         +-----------------------------+-----------------------------+
                                       |
                                       v
                     [ Dynamic NSG & Disk Ingestion ]
                     - dynamic "security_rule" (Priority, Ports)
                     - dynamic "data_disk" (LUNs, Storage SKUs)
```

---

## 📦 Data Contract & Input Definitions

### 1. Complex Nested VNet & Subnet Contract (`variables.tf`)
```hcl
variable "vnets_nested_map" {
  description = "Complex nested map of Virtual Networks and Subnets."
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
}
```

### 2. Flattening Transformation Logic (`main.tf`)
```hcl
locals {
  # Flattens nested map into a single deterministic map with key: "${vnet_key}.${subnet_key}"
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
}
```

---

## 🚀 Quickstart & Deployment

### Step 1: Clone Repository
```bash
git clone https://github.com/sadiq84/terraform-azure-nested-map-modules.git
cd terraform-azure-nested-map-modules
```

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Validate & Lint
```bash
terraform fmt -check
terraform validate
```

### Step 4: Plan Execution
```bash
terraform plan -var-file="terraform.tfvars.example" -out=tfplan
```

### Step 5: Apply Infrastructure
```bash
terraform apply tfplan
```

---

## 🛡️ Production Verification & Tests

- **Shift-Left Security**: Validated with `checkov -d . --framework terraform`
- **Linting**: Passed strict `tflint --recursive` rules
- **State Integrity**: Verified zero unplanned resource destructions during in-place property modifications

---

## 👨‍💻 Author & Maintainer
**Mohammad Sadique Qutub**  
*Senior DevSecOps & Cloud Solutions Architect*  
GitHub: [@sadiq84](https://github.com/sadiq84) • Email: [mohd.sadiq84@gmail.com](mailto:mohd.sadiq84@gmail.com)
