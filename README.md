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
6. Deploy kube-vip, MetalLB, and Traefik
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
    k3s_ingress/         MetalLB and Traefik
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

The baseline role never reboots on its own; it reports when a reboot is
required. Only the rebuild playbook reboots, before anything is running.
Configuration that could block access, such as `sudoers` and `sshd`, is
validated before being written.

Platform components are deployed through the k3s Helm controller using
`HelmChart` manifests, rather than a separate Helm or GitOps installation.

API failover has been tested by hard-stopping the server holding the virtual
IP. The address moves to another server and the API remains reachable while
etcd keeps quorum on the remaining two.

## Roadmap

- cert-manager with a wildcard certificate for internal services
- Argo CD for application delivery
- Longhorn for replicated storage
- Additional projects under their own playbook folders