locals {
  k8s_servers = {
    k8s01 = { number = 1, vm_id = 110, ip = "172.16.250.11" }
    k8s02 = { number = 2, vm_id = 111, ip = "172.16.250.12" }
    k8s03 = { number = 3, vm_id = 112, ip = "172.16.250.13" }
  }
}

# The VM used to be a single resource named k8s01; this tells Terraform it's
# the same VM under its new address, so it isn't destroyed and recreated.
moved {
  from = proxmox_virtual_environment_vm.k8s01
  to   = proxmox_virtual_environment_vm.k8s["k8s01"]
}

resource "proxmox_virtual_environment_vm" "k8s" {
  for_each = local.k8s_servers

  node_name     = "pve01"
  vm_id         = each.value.vm_id
  name          = each.key
  description   = "k3s server ${each.value.number} - managed by Terraform"
  tags          = ["terraform", "k3s", "server"]
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  agent {
    enabled = true
    trim    = true
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 40
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 250
  }

  initialization {
    datastore_id = "local-zfs"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "172.16.250.1"
      }
    }

    dns {
      servers = ["172.16.250.1"]
      domain  = "lunartech.cloud"
    }
  }
}