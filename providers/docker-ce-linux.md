# docker-ce on Linux

**Tested:** Docker 29.x, Ubuntu 26.04 arm64 in Parallels, October 2026.

DDEV's recommended provider on Linux. The daemon runs as root on the host, so there's no VM, no file-sharing layer, and no privileged-port problem.

## Setup

See DDEV's [Docker installation docs](https://docs.ddev.com/en/stable/users/install/docker-installation/). If the daemon doesn't come back after a reboot, it isn't enabled: `sudo systemctl enable --now docker`.

## SSH agent

`ssh_agent_upstream=host` uses `$SSH_AUTH_SOCK` from the shell running `ddev`, and DDEV mounts the socket's directory into `ddev-ssh-agent`. Nothing is captured at startup, so this is the simplest case.

- **`ssh -A`:** each login gets a new socket; run `ddev auth ssh` again after logging in again.
- **VS Code Remote:** `SSH_AUTH_SOCK` is a symlink such as `/tmp/vscode-ssh-auth-sock-*`. DDEV relays to its target. After VS Code reconnects, a terminal opened earlier still points at the old, dead socket; DDEV reports it as stale. Open a new terminal.
- **Desktop agent:** its socket doesn't change, so set it directly, for example `ddev config global --ssh-agent-upstream=/run/user/$(id -u)/gcr/ssh` on Ubuntu.
- **Socket in the home directory:** a socket at `~/.1password-agent.sock` makes DDEV mount all of `~` into `ddev-ssh-agent`. Use `~/.1password/agent.sock` or another dedicated directory.

Tested: symlink to a forwarded 1Password agent (keys listed, GitHub authenticated); symlink into a removed directory (stale message); symlink into an existing directory with no socket ("No SSH agent is listening").
