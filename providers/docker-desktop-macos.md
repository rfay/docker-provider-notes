# Docker Desktop for macOS

**Tested:** Docker Desktop on macOS (Apple Silicon), context `desktop-linux`, Docker 29.8.2, October 2026.

## Setup

DDEV's [Docker installation docs](https://docs.ddev.com/en/stable/users/install/docker-installation/) cover it. Restart it with `docker desktop restart`; quitting the app with `osascript -e 'quit app "Docker"'` once left the backend running with its VM stopped (`no route to host` to `192.168.127.7:2376`), and `open -a Docker` didn't recover it.

## SSH agent

Docker Desktop provides the host's agent at `/run/host-services/ssh-auth.sock` inside its VM. It relays the `SSH_AUTH_SOCK` its backend got at startup:

- **Launched from the Dock or `open -a Docker`:** launchd's value, normally `/var/run/com.apple.launchd.*/Listeners` (the macOS agent), or whatever `launchctl setenv SSH_AUTH_SOCK ...` set
- **Restarted with `docker desktop restart`:** the environment of the shell that ran it

Check what it has: `ps eww -p $(pgrep -f "com.docker.backend$") | tr ' ' '\n' | grep SSH_AUTH_SOCK`

A common 1Password setup makes the launchd `Listeners` socket a symlink to 1Password's `agent.sock`, so the macOS agent and 1Password list the same keys.

It doesn't read `IdentityAgent` from `~/.ssh/config`. Point the system-wide `SSH_AUTH_SOCK` at the agent instead; for 1Password see [Configure SSH_AUTH_SOCK globally](https://developer.1password.com/docs/ssh/agent/compatibility/). Related: [docker/for-mac#7204](https://github.com/docker/for-mac/issues/7204), [docker/for-mac#7556](https://github.com/docker/for-mac/issues/7556).

**Fixed path, tested:** with `launchctl setenv SSH_AUTH_SOCK ~/.ssh-agent-forward/agent.sock` and a Docker Desktop restart, switching the symlink between two agents without restarting gave each agent's key in turn. With the target agent stopped, `ssh-add -l` through the relay hung, as on Linux. This is mainly useful for `ssh -A` into a Mac; see [docker-desktop-linux.md](docker-desktop-linux.md#following-ssh--a-logins-without-restarting) for the `~/.ssh/rc` side.
