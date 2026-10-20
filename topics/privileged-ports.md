# Privileged Ports in VM-Based Providers

**Tested:** Colima and Lima on Ubuntu 26.04 amd64, October 2026.

## Symptom

`ddev start` succeeds and the router is healthy, but `https://<project>.ddev.site` doesn't answer. `ddev exec curl localhost` works, and so do higher ports such as Mailpit's 8025 or the web container's direct port.

## Cause

Lima, and Colima on top of it, forward each port published inside the VM to the host with `ssh -L`, running as the user. Linux lets unprivileged users bind only ports at or above `net.ipv4.ip_unprivileged_port_start`, 1024 by default. The router's 80 and 443 fail, Lima logs it as negligible, and carries on:

```text
failed to set up forwarding tcp port 443 (negligible if already forwarded) ... exit status 255
```

The log is `~/.config/colima/_lima/colima/ha.stderr.log` for Colima, `~/.lima/<instance>/ha.stderr.log` for Lima. `ss -ltn | grep -E ':(80|443) '` shows nothing listening.

Neither Colima nor Lima documents this for Linux hosts. [lima-vm/lima#45](https://github.com/lima-vm/lima/issues/45) covers privileged ports on macOS only; [lima-vm/lima#4321](https://github.com/lima-vm/lima/issues/4321) shows the same bind failure for UDP port 323 on Linux.

## Fixes

```bash
# Allow unprivileged binds from port 80 up (needs sudo), then restart the VM so Lima retries
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/99-lima-ports.conf
sudo sysctl --system
colima stop && colima start        # or: limactl stop <instance> && limactl start <instance>

# Or move DDEV's router to high ports (URLs become https://<project>.ddev.site:8443)
ddev config global --router-http-port=8080 --router-https-port=8443
ddev restart
```

## Why other providers differ

- **docker-ce:** the daemon runs as root.
- **Rootless Docker and Podman:** the engine's port forwarder binds as the user while the container starts, so the start fails with an error. DDEV's install docs set the sysctl for rootless setups.
- **Docker Desktop for Linux:** its backend has extra privileges for binding low ports.
- **Colima and Lima:** the container starts as root in the VM, and the host-side forward fails later, quietly. DDEV checks before starting that the ports are free, but nothing checks afterwards that they answer on the host.
