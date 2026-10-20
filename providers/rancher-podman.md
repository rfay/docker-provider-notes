# Rancher Desktop and Podman

**Tested:** not retested here; from DDEV's docs and code, October 2026.

## SSH agent

On macOS, neither forwards a host agent that DDEV can use. With `ssh_agent_upstream=host`, DDEV warns and falls back to its own agent; add key files with `ddev auth ssh` as usual.

## Ports

Rootless Podman and rootless Docker bind published ports on the host as the user, so ports 80 and 443 fail at container start when `net.ipv4.ip_unprivileged_port_start` is 1024. DDEV's install docs set it to 0 for rootless setups. See [Privileged ports](../topics/privileged-ports.md).
