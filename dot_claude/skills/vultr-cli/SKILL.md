---
name: vultr-cli
description: >
  Manage Vultr cloud resources via the vultr-cli command-line tool. Use when creating, listing, deleting,
  or updating instances, SSH keys, DNS records, block storage, firewalls, snapshots, VPCs, reserved IPs, ISOs,
  startup scripts, or any other Vultr API operations. Triggers on: vultr-cli, vultr instance, vultr ssh key,
  create server, list instances, vultr dns, vultr firewall, vultr snapshot, vultr vpc, vultr block storage,
  vultr api, deploy instance, destroy instance, vultr plan, vultr region.
---

# Vultr CLI

Command-line interface for the Vultr API (v2). Config: `~/.vultr-cli.yaml`.

For first-time installation and authentication, see [references/setup.md](references/setup.md).

## Commands

```bash
# Instances
vultr-cli instance list [-o json]
vultr-cli instance get <ID>
vultr-cli instance create --region ewr --plan vc2-1c-1gb --os 1743 --ssh-keys <KEY-ID> --host myserver
vultr-cli instance delete <ID>          # alias: destroy
vultr-cli instance start|stop|restart <ID>
vultr-cli instance reinstall <ID>       # wipes data
vultr-cli instance label <ID> --label "name"
vultr-cli instance tags <ID> --tags "t1,t2"
vultr-cli instance plan <ID> --plan <SLUG>
vultr-cli instance update-firewall-group <ID> --firewall-group <FW-ID>

# SSH Keys
vultr-cli ssh-key list|get <ID>|delete <ID>
vultr-cli ssh-key create --name "name" --key "ssh-rsa ..."

# DNS
vultr-cli dns domain list
vultr-cli dns domain create --domain example.com --ip 1.2.3.4
vultr-cli dns record list --domain example.com
vultr-cli dns record create --domain example.com --type A --name www --data 1.2.3.4 --ttl 300

# Block Storage
vultr-cli block-storage list
vultr-cli block-storage create --region ewr --size_gb 50 --label "name"
vultr-cli block-storage attach|detach <ID> --instance-id <INST-ID>
vultr-cli block-storage resize <ID> --size_gb 100
vultr-cli block-storage delete <ID>

# Firewalls
vultr-cli firewall group list
vultr-cli firewall group create --name "name" --description "desc"
vultr-cli rule list --firewall-group-id <ID>
vultr-cli firewall rule create --firewall-group-id <ID> --protocol tcp --port 22 --subnet 10.0.0.0 --subnet-size 8

# Snapshots
vultr-cli snapshot list
vultr-cli snapshot create --instance-id <ID> --description "desc"
vultr-cli snapshot delete <ID>

# VPCs
vultr-cli vpc list
vultr-cli vpc create --region ewr --description "desc" --subnet 10.99.0.0 --subnet-size 24
vultr-cli vpc delete <ID>

# Reserved IPs
vultr-cli reserved-ip list
vultr-cli reserved-ip create --region ewr --type v4
vultr-cli reserved-ip attach|detach <ID> --instance-id <INST-ID>
vultr-cli reserved-ip delete <ID>

# ISOs / Startup Scripts
vultr-cli iso list
vultr-cli iso create --url <URL>
vultr-cli iso delete <ID>
vultr-cli script list
vultr-cli script create --name "name" --script "#!/bin/bash\n..."
vultr-cli script delete <ID>

# Discovery
vultr-cli regions list
vultr-cli plans list
vultr-cli os list
vultr-cli apps list
```

## Notes

- Output: `-o text` (default), `-o json`, `-o yaml`. Use JSON with `jq` for scripting.
- `--os` is a numeric ID. Look up with `vultr-cli os list`.
- `--plan` is a slug (e.g. `vc2-1c-1gb`). See `vultr-cli plans list`.
- `--region` is an ID (e.g. `ewr`, `ord`, `sea`). See `vultr-cli regions list`.
- `--ssh-keys` takes comma-separated UUIDs.
- `--host` sets reverse DNS. `--userdata` or `userdata-file` for cloud-init.
- Use `--image`, `--app`, `--iso`, or `--snapshot` instead of `--os` for non-standard installs.
