# homelab

Single source of truth for the lunartech.cloud homelab.

| Path | What |
|---|---|
| `terraform/` | Proxmox VM definitions (bpg/proxmox provider) |
| `ansible/` | Host configuration — run from `ansible/` |
| `kubernetes/` | Cluster manifests / Argo CD apps |
| `scripts/` | Helper scripts |

Control node: taskmaster (172.16.100.60).
