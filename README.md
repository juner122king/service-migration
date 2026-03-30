# Service Migration Kit

This directory contains a repeatable migration kit for the services currently running on this machine:

- `CLIProxyAPI`
- `new-api`
- `CPA-Dashboard`
- `sing-box`

## Files
- `target.env.example`: copy to `target.env` and edit for the destination host.
- `bootstrap-target.sh`: optional target bootstrap for Debian/Ubuntu-like hosts.
- `sync-services.sh`: run on the source machine to push files to the target host over SSH.
- `build-offline-bundle.sh`: run on the source machine to create a tarball for offline transfer.
- `extract-offline-bundle.sh`: run on the target host after copying the tarball.
- `install-target.sh`: run on the target host to install service files and restart services.
- `check-services.sh`: run on the target host after install.
- `CURRENT_MACHINE_INVENTORY.md`: source-side inventory used to build this kit.

## Source prerequisites
- `rsync`
- `ssh` for the online sync path
- `tar`
- Read access to `/etc/sing-box`, `/etc/systemd/system/cpa-dashboard.service`, and `/lib/systemd/system/sing-box.service`
- `rsync` installed on the target host too for the online sync path

## Target prerequisites
- Linux with `systemd`
- Docker Engine with Compose plugin
- `python3` and `python3-venv`
- `rsync`
- `tar`
- `sudo`

## Online migration
1. Copy `target.env.example` to `target.env` and set `TARGET_HOST`.
2. If the target username or home path differs, set `TARGET_USER`, `TARGET_HOME`, `SERVICE_USER`, and `SERVICE_GROUP`.
3. If needed, bootstrap the target host first:
   - `sudo bash ~/service-migration/bootstrap-target.sh`
4. Run on the source machine:
   - `bash /home/juner122king/service-migration/sync-services.sh /home/juner122king/service-migration/target.env`
5. Run on the target host:
   - `bash ~/service-migration/install-target.sh ~/service-migration/target.env`
6. Validate on the target host:
   - `bash ~/service-migration/check-services.sh ~/service-migration/target.env`

## Offline migration
1. Copy `target.env.example` to `target.env` and edit it for the destination host.
2. Build the bundle on the source machine:
   - `bash /home/juner122king/service-migration/build-offline-bundle.sh /home/juner122king/service-migration/target.env /home/juner122king/service-migration/service-migration-bundle.tar.gz`
3. Transfer `service-migration-bundle.tar.gz` to the target host by SCP, object storage, or manual upload.
4. Place the `service-migration` directory on the target host if it is not already there.
5. On the target host, extract the bundle into the local kit:
   - `bash ~/service-migration/extract-offline-bundle.sh /path/to/service-migration-bundle.tar.gz`
6. Optional bootstrap on the target host:
   - `sudo bash ~/service-migration/bootstrap-target.sh`
7. Install services on the target host:
   - `bash ~/service-migration/install-target.sh ~/service-migration/target.env`
8. Validate on the target host:
   - `bash ~/service-migration/check-services.sh ~/service-migration/target.env`

## Default behavior
- Sync or pack service data and config.
- Skip `.git/` and logs unless explicitly enabled in `target.env`.
- Preserve current secrets and databases.
- Rewrite `cpa-dashboard.service` to match target user/group/home.
- Install `sing-box.service` into `/etc/systemd/system/` so the target no longer depends on `/lib/systemd/system/` packaging state.

## Recommended hardening after migration
- Restrict firewall exposure to only the ports you actually need.
- Rotate `CLIProxyAPI` management and API credentials after cutover.
- Put public HTTP services behind HTTPS if the target host is Internet-facing.
