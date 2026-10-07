# homelab

Infrastructure as code for a Proxmox-based homelab. Terraform provisions the
VMs, Ansible configures them, and the result is a three-server k3s cluster that
can be destroyed and rebuilt from scratch with a single playbook.

## Stack

- Proxmox VE on a Dell R730xd
- Terraform with the `bpg/proxmox` provider
- Ansible for OS and cluster configuration
- k3s (embedded etcd, three control-plane servers)
- kube-vip for a highly available API address
- MetalLB in L2 mode for LoadBalancer services
- Traefik for ingress
- Argo CD for application delivery
- Prometheus, Alertmanager and Grafana (kube-prometheus-stack) for monitoring
- External Secrets to sync app Secrets from AWS SSM Parameter Store
- kured for rolling reboots after updates
- AWS SSM Parameter Store for credentials

## Rebuild

```bash
cd ansible
ansible-playbook playbooks/kubernetes/rebuild.yml
```

The rebuild playbook runs the full lifecycle in order:

1. Destroy and recreate the cluster VMs with Terraform
2. Wait for each VM to boot, trust its new host key, and wait for cloud-init
3. Create the `ansible` service account
4. Apply the OS baseline, then reboot if updates require it
5. Install k3s, joining servers one at a time
6. Deploy kube-vip, monitoring, MetalLB, Traefik, Argo CD, External Secrets,
   and kured
7. Write a kubeconfig and matching `kubectl` to the control node

All playbooks are idempotent. A second run reports no changes.

## Layout

```
terraform/
  kubernetes/            cluster VMs
ansible/
  ansible.cfg
  inventory/
    hosts.yml            hosts, grouped by project
    group_vars/          shared settings per group
  playbooks/
    common/              applied to every server (bootstrap, baseline)
    kubernetes/          cluster build and rebuild
  roles/
    automation_user/     service account and SSH key handover
    baseline/            patching, tools, chrony, journald, SSH hardening
    k3s_prep/            swap, kernel modules, sysctls
    k3s_server/          k3s install and join, kube-vip, kubeconfig
    k3s_monitoring/      Prometheus, Alertmanager, Grafana
    k3s_ingress/         MetalLB and Traefik
    k3s_argocd/          Argo CD and the apps it deploys
    k3s_external_secrets/ External Secrets and the app Secrets it syncs
    k3s_app_secrets/     fallback: copies app Secrets once
    k3s_kured/           rolling reboots
```

Roles contain the logic. Playbooks only map roles to host groups. Playbooks
shared by every server live in `common/`, and each project has its own folder.

## Implementation notes

Secrets are never stored in the repository. Terraform reads the Proxmox API
token from Parameter Store as an ephemeral value, so it is kept out of state as
well. The k3s join token is read from the first server at run time.

Automation connects as a dedicated, key-only `ansible` account. The bootstrap
role detects first-time setup automatically, falls back to the cloud-init user
to create the account, then removes the automation key from that user.

taskmaster, the control node Ansible runs from, is in the inventory as
`control` with a local connection. It gets the baseline but is skipped by the
bootstrap playbook, so it never gets the automation account.

The baseline role never reboots on its own; it reports when a reboot is
required. Only the rebuild playbook reboots, before anything is running.
Configuration that could block access, such as `sudoers` and `sshd`, is
validated before being written.

Platform components are deployed through the k3s Helm controller using
`HelmChart` manifests, rather than a separate Helm or GitOps installation.

API failover has been tested by hard-stopping the server holding the virtual
IP. The address moves to another server and the API remains reachable while
etcd keeps quorum on the remaining two.

## Monitoring

Grafana is at `grafana.lunartech.cloud`, which needs a DNS record pointing at
the Traefik address, `172.16.250.200`. Prometheus scrapes the nodes, kubelets,
the API server, etcd (k3s exposes its metrics on port 2381), Argo CD, External
Secrets, kured, and any app that ships a ServiceMonitor or PodMonitor. Apps can
also ship Grafana dashboards as ConfigMaps labelled `grafana_dashboard=1`.

Alertmanager sends warnings and critical alerts to Discord once a webhook URL
is stored in `/homelab/monitoring/discord-webhook`; kured posts reboot notices
to the same webhook.

## Optional parameters

The playbook works without these and reports what it skipped. Add them to
Parameter Store (SecureString) and rerun `playbooks/kubernetes/k3s.yml`.

| Parameter | Used for |
|---|---|
| `/homelab/argocd/admin-password` | Argo CD admin password (20+ characters); the initial admin Secret is deleted once it's set |
| `/homelab/monitoring/grafana-admin-password` | Grafana admin password |
| `/homelab/monitoring/discord-webhook` | Alert and reboot notices |
| `/homelab/external-secrets/access-key-id`, `/homelab/external-secrets/secret-access-key` | Keys for an IAM user that can read the app parameters; without them, Ansible copies the app Secrets once instead of External Secrets keeping them in sync |

## Roadmap

- cert-manager with a wildcard certificate for internal services
- An enterprise SSD (with power-loss protection) for the VM disks: etcd's
  fsyncs on the current consumer SSD take hundreds of milliseconds
- Longhorn for replicated storage
- Additional projects under their own playbook folders