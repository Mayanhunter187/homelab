# Read-only connectivity check - creates nothing.
data "proxmox_virtual_environment_version" "pve" {}

data "proxmox_virtual_environment_vms" "all" {
  node_name = "pve01"
}

output "pve_version" {
  value = data.proxmox_virtual_environment_version.pve.version
}

output "vms" {
  value = { for vm in data.proxmox_virtual_environment_vms.all.vms : vm.vm_id => vm.name }
}
