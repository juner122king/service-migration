# Service Migration Kit

A repeatable migration toolkit for moving a multi-service deployment from one Linux server to another.

This repository was built around a real deployment that includes:
- `CLIProxyAPI`
- `new-api`
- `CPA-Dashboard`
- `sing-box`

It supports two migration paths:
- Online migration over `ssh` + `rsync`
- Offline migration using a generated `.tar.gz` bundle

## What This Solves

When a server runs several services with mixed runtime models, migration usually becomes messy:
- some services run with Docker Compose
- some run with `systemd`
- some store important state in local directories
- some require service unit files outside the project directory

This toolkit standardizes that process.

It lets you:
- collect the application files, config, and persistent data you actually need
- move them to another server with a predictable layout
- re-install service units on the target machine
- restart services in a defined order
- validate the final state with a simple health check script

## Services Covered

### `CLIProxyAPI`
- Runtime: Docker Compose
- Source path: `/home/juner122king/CLIProxyAPI`
- Main persisted data: `config.yaml`, `auths/`, optionally `logs/`

### `new-api`
- Runtime: Docker Compose
- Source path: `/home/juner122king/newapi`
- Main persisted data: `data/one-api.db`, optionally `logs/`

### `CPA-Dashboard`
- Runtime: `systemd`
- Source path: `/home/juner122king/CPA-Dashboard`
- Service unit: `/etc/systemd/system/cpa-dashboard.service`
- Dependency: local `CLIProxyAPI` config or install directory

### `sing-box`
- Runtime: `systemd`
- Source path: `/etc/sing-box`
- Service unit source: `/lib/systemd/system/sing-box.service`

## Migration Model

The toolkit separates migration into three stages:

1. Collect
- gather service files, unit files, config, and persistent state

2. Install
- place files into the expected target paths
- install or rewrite `systemd` units where needed
- start Docker Compose stacks and systemd services

3. Verify
- check Docker containers
- check systemd services
- check local ports and HTTP endpoints

## Repository Layout

- `target.env.example`
  - template for target-host-specific values
- `bootstrap-target.sh`
  - optional dependency installer for Debian/Ubuntu-like targets
- `sync-services.sh`
  - online migration from source to target over SSH
- `build-offline-bundle.sh`
  - create an offline tarball bundle from the source machine
- `extract-offline-bundle.sh`
  - unpack an offline bundle on the target host
- `install-target.sh`
  - install files and restart services on the target host
- `check-services.sh`
  - post-install validation checks
- `CURRENT_MACHINE_INVENTORY.md`
  - inventory snapshot of the source deployment

## Requirements

### Source machine
- Linux shell environment
- `rsync`
- `tar`
- `ssh` for online migration
- read access to:
  - `/etc/sing-box`
  - `/etc/systemd/system/cpa-dashboard.service`
  - `/lib/systemd/system/sing-box.service`

### Target machine
- Linux with `systemd`
- `docker`
- Docker Compose plugin
- `python3`
- `python3-venv`
- `rsync`
- `tar`
- `sudo`

## Configuration

Copy the template:

```bash
cp target.env.example target.env
```

Key settings in `target.env`:

```bash
TARGET_HOST=203.0.113.10
TARGET_USER=juner122king
TARGET_SSH_PORT=22
TARGET_HOME=/home/juner122king
SERVICE_USER=juner122king
SERVICE_GROUP=juner122king
```

Feature flags:

```bash
SYNC_CLIPROXY=1
SYNC_NEWAPI=1
SYNC_CPA_DASHBOARD=1
SYNC_SING_BOX=1
INCLUDE_LOGS=0
INCLUDE_GIT_DIRS=0
```

Notes:
- keep `INCLUDE_LOGS=0` unless you explicitly want historical logs
- keep `INCLUDE_GIT_DIRS=0` for deployment-only migration
- if the target username or home path changes, update both `TARGET_HOME` and `SERVICE_USER` / `SERVICE_GROUP`

## Quick Start

### Option 1: Online migration

Run this when the source server can reach the target server by SSH.

1. Prepare target config:

```bash
cp target.env.example target.env
```

2. Edit `target.env`.

3. Optional: bootstrap the target host:

```bash
sudo bash ~/service-migration/bootstrap-target.sh
```

4. Push files from source to target:

```bash
bash /home/juner122king/service-migration/sync-services.sh \
  /home/juner122king/service-migration/target.env
```

5. On the target host, install and start services:

```bash
bash ~/service-migration/install-target.sh \
  ~/service-migration/target.env
```

6. Validate on the target host:

```bash
bash ~/service-migration/check-services.sh \
  ~/service-migration/target.env
```

### Option 2: Offline migration

Run this when the source server cannot directly reach the target server.

1. Prepare target config on the source machine:

```bash
cp target.env.example target.env
```

2. Build the migration bundle:

```bash
bash /home/juner122king/service-migration/build-offline-bundle.sh \
  /home/juner122king/service-migration/target.env \
  /home/juner122king/service-migration/service-migration-bundle.tar.gz
```

3. Transfer the bundle to the target host using any available method.

4. Ensure the `service-migration` repo exists on the target host, then extract:

```bash
bash ~/service-migration/extract-offline-bundle.sh \
  /path/to/service-migration-bundle.tar.gz
```

5. Optional: bootstrap the target host:

```bash
sudo bash ~/service-migration/bootstrap-target.sh
```

6. Install and validate:

```bash
bash ~/service-migration/install-target.sh ~/service-migration/target.env
bash ~/service-migration/check-services.sh ~/service-migration/target.env
```

## Example Workflows

### Example: full online migration

Source machine:

```bash
cd /home/juner122king/service-migration
cp target.env.example target.env
sed -i 's/203.0.113.10/198.51.100.25/' target.env
bash sync-services.sh target.env
```

Target machine:

```bash
cd ~/service-migration
bash install-target.sh target.env
bash check-services.sh target.env
```

### Example: offline bundle for later import

Source machine:

```bash
cd /home/juner122king/service-migration
cp target.env.example target.env
bash build-offline-bundle.sh target.env /tmp/service-migration-bundle.tar.gz
```

Target machine:

```bash
mkdir -p ~/service-migration
cd ~/service-migration
bash extract-offline-bundle.sh /tmp/service-migration-bundle.tar.gz
bash install-target.sh target.env
bash check-services.sh target.env
```

## Default Behavior

By default the toolkit:
- migrates all four services
- excludes `.git/`
- excludes logs and `*.log`
- preserves credentials, auth files, and databases
- rewrites `cpa-dashboard.service` to match the target user and target home path
- installs `sing-box.service` into `/etc/systemd/system/`

## Validation Behavior

`check-services.sh` verifies:
- Docker container `cli-proxy-api` is running
- port `127.0.0.1:8317` is reachable
- Docker container `new-api` is running
- `http://127.0.0.1:3480/api/status` responds successfully
- `cpa-dashboard.service` is active
- port `127.0.0.1:5000` is reachable
- `sing-box.service` is active

## Security Notes

This toolkit is intentionally operational, not opinionated.
It preserves the current deployment state unless you change the config.

That means:
- secrets are copied as-is
- API keys are copied as-is
- auth directories are copied as-is
- database state is copied as-is

Recommended after cutover:
- rotate management credentials
- rotate API keys where practical
- restrict open firewall ports
- place public HTTP services behind HTTPS
- review whether `remote-management` should remain remotely accessible

## Git Usage

Tracked in Git:
- scripts
- docs
- `target.env.example`

Not tracked in Git:
- `target.env`
- generated tarballs
- extracted staging directories
- rendered local files

## Troubleshooting

### `Missing required command: rsync`
Install `rsync` on the relevant machine.

### `docker compose plugin is required`
Install Docker Compose plugin on the target host.

### `Failed to connect to bus`
Run service installation and verification on a real system with `systemd`, not in a restricted shell sandbox.

### `permission denied while trying to connect to the docker API`
Run as a user with access to Docker, or use `sudo` where appropriate.

## License

No license file has been added yet. If you plan to publish or reuse this outside your own infrastructure, add one explicitly.
