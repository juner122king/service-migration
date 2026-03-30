# Current Machine Inventory

Source machine snapshot date: 2026-03-30 UTC

## Services in scope

### CLIProxyAPI
- Path: `/home/juner122king/CLIProxyAPI`
- Runtime: Docker Compose
- Container: `cli-proxy-api`
- Image: `eceasy/cli-proxy-api:latest`
- Ports: `8317`, `8085`, `1455`, `54545`, `51121`, `11451`
- Persistent paths:
  - `config.yaml`
  - `auths/`
  - `logs/`

### new-api
- Path: `/home/juner122king/newapi`
- Runtime: Docker Compose
- Container: `new-api`
- Image: `calciumion/new-api:latest`
- Port: `3480`
- Persistent paths:
  - `data/one-api.db`
  - `logs/`
  - `compose.yaml`

### CPA-Dashboard
- Path: `/home/juner122king/CPA-Dashboard`
- Runtime: systemd
- Unit: `/etc/systemd/system/cpa-dashboard.service`
- Start command: `/bin/bash /home/juner122king/CPA-Dashboard/start-linux.sh`
- App port: `5000`
- Dependency: local `CLIProxyAPI` config or install directory

### sing-box
- Path: `/etc/sing-box`
- Runtime: systemd
- Unit source on current machine: `/lib/systemd/system/sing-box.service`
- Key files:
  - `/etc/sing-box/config.json`
  - `/etc/sing-box/conf/`
  - `/etc/sing-box/bin/sing-box`
  - `/etc/sing-box/bin/tls.cer`
  - `/etc/sing-box/bin/tls.key`

## Copy policy implemented by the scripts
- Sync `CLIProxyAPI`, `newapi`, `CPA-Dashboard`, and `sing-box` by default.
- Exclude `.git/` by default.
- Exclude `logs/` and `*.log` by default.
- Keep credentials and databases intact.
- Rewrite `cpa-dashboard.service` on the target to match target user/group/home.
