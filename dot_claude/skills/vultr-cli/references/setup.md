# Vultr CLI Setup

First-time installation and authentication of `vultr-cli`.

## Install

Release assets are version-stamped (e.g. `vultr-cli_v3.10.0_linux_amd64.tar.gz`), so the
version-less `releases/latest/download/...` path 404s. Resolve the asset URL from the GitHub
API and install to a user-writable bin dir (no sudo needed):

```bash
URL=$(curl -fsSL https://api.github.com/repos/vultr/vultr-cli/releases/latest \
  | python3 -c "import sys,json;[print(a['browser_download_url']) for a in json.load(sys.stdin)['assets'] if 'linux_amd64.tar.gz' in a['name']]")
curl -fsSL -o /tmp/vultr-cli.tar.gz "$URL"
mkdir -p ~/.local/bin
tar -xzf /tmp/vultr-cli.tar.gz -C ~/.local/bin vultr-cli
chmod +x ~/.local/bin/vultr-cli
vultr-cli version   # ~/.local/bin must be on PATH
```

## API Key

Generate an API key at [my.vultr.com/settings/#settingsapi](https://my.vultr.com/settings/#settingsapi).

Store it in the config file:

```yaml
# ~/.vultr-cli.yaml
api-key: VULTR_API_KEY
rate-limit: 700ms
```

Or set the environment variable:

```bash
export VULTR_API_KEY=VULTR_API_KEY
```

### IP Whitelisting

Vultr API keys can restrict access by source IP. The key must whitelist the host's egress IPs — these may differ from bound interface IPs. Check with:

```bash
curl -4 -s ifconfig.me   # IPv4 egress
curl -6 -s ifconfig.me   # IPv6 egress
```

Add both in Vultr control panel → API → IP Whitelist. If only IPv4 is whitelisted on a dual-stack host, Go prefers AAAA and will fail — either whitelist both, or force IPv4 with `/etc/hosts`: `66.55.134.139 api.vultr.com`. Verify: `vultr-cli account info`.

## SSH Key

Create a dedicated key (only needed if you'll deploy instances you SSH into):

```bash
KEY_NAME="claude-$(hostname)"
ssh-keygen -t ed25519 -f ~/.ssh/vultr_cli -C "$KEY_NAME"
vultr-cli ssh-key create --name "$KEY_NAME" --key "$(cat ~/.ssh/vultr_cli.pub)"
```

Record the returned key ID for `--ssh-keys` in instance creation.
