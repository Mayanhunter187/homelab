resource "proxmox_virtual_environment_vm" "k8s01" {
  node_name     = "pve01"
  vm_id         = 110
  name          = "k8s01"
  description   = "k3s server 1 - managed by Terraform"
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
    trim = true
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
        address = "172.16.250.11/24"
        gateway = "172.16.250.1"
      }
    }

    dns {
      servers = ["172.16.250.1"]
      domain  = "lunartech.cloud"
    }
  }
}