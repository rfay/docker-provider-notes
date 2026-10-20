# Docker Desktop for Linux

**Tested:** Docker Desktop 4.96.0, Ubuntu 26.04 amd64 on EC2 with KVM, October 2026. Context: [ddev/ddev#8963](https://github.com/ddev/ddev/pull/8963).

DDEV doesn't test Docker Desktop for Linux and steers Linux users to docker-ce. These notes explain why, and what works anyway.

## Setup

Requirements, from [Docker's install page](https://docs.docker.com/desktop/setup/install/linux/):

- amd64 only; there are `.deb` and `.rpm` packages for Ubuntu, Debian, RHEL, and Fedora
- KVM, with your user in the `kvm` group; Docker doesn't support it in nested virtualization
- QEMU 5.2 or later, systemd, at least 4 GB of RAM
- A desktop session (GNOME, KDE, or MATE) and an initialized `pass`

It runs as a systemd user service (`systemctl --user start docker-desktop`) and uses the `desktop-linux` Docker context. It is a GUI app: there's no supported headless mode, so a CI runner or an SSH-only server can't run it. Its VM got 3.8 GB of RAM on a 14 GB host.

## Usage problems

- **Container starts deadlock.** Three times in one day of testing, every `docker run` and `docker start` hung with the container stuck in `Created`, while `docker ps` and `docker exec` still worked, and the project's site stopped answering. `ddev poweroff` hangs too. Only restarting Docker Desktop recovers. See [Docker Desktop deadlocks](../topics/docker-desktop-deadlocks.md).
- **The agent forwarder hangs on a dead agent** instead of failing. See below.

## SSH agent

Docker Desktop provides the host's agent at `/run/host-services/ssh-auth.sock` inside its VM, so `ssh_agent_upstream=host` works. It relays the `SSH_AUTH_SOCK` found in the **systemd user environment when Docker Desktop started**, not the current shell's.

- Check what it captured: `systemctl --user show-environment | grep SSH_AUTH_SOCK`
- Use the current shell's agent: `systemctl --user import-environment SSH_AUTH_SOCK && systemctl --user restart docker-desktop` (this stops running projects)
- [docker/desktop-linux#225](https://github.com/docker/desktop-linux/issues/225): under systemd, Docker Desktop may not get `SSH_AUTH_SOCK` at all

**When the captured agent is gone, the forwarder hangs.** A connection to `/run/host-services/ssh-auth.sock` stays open with no answer, so `ssh-add -l` in a container hangs, where the same command against the dead socket on the host fails immediately. This seems unreported. DDEV's `ddev auth ssh` times out after 2 minutes and prints the restart command.

### Following `ssh -A` logins without restarting

Each `ssh -A` login gets a new socket. Docker Desktop follows a symlink on every request, so give it a fixed path once and repoint the path at each login:

```bash
# Once
mkdir -p -m 700 ~/.ssh-agent-forward
systemctl --user set-environment SSH_AUTH_SOCK=$HOME/.ssh-agent-forward/agent.sock
systemctl --user restart docker-desktop
```

```bash
# ~/.ssh/rc, which sshd runs at each login
if [ -n "$SSH_AUTH_SOCK" ]; then
  mkdir -p -m 700 ~/.ssh-agent-forward
  ln -sf "$SSH_AUTH_SOCK" ~/.ssh-agent-forward/agent.sock
fi
# With X11 forwarding on, an rc file stops sshd from running xauth itself (see sshd(8))
if read proto cookie && [ -n "$DISPLAY" ]; then
  if [ "$(echo "$DISPLAY" | cut -c1-10)" = 'localhost:' ]; then
    echo add unix:$(echo "$DISPLAY" | cut -c11-) "$proto" "$cookie"
  else
    echo add "$DISPLAY" "$proto" "$cookie"
  fi | xauth -q -
fi
```

Tested with two consecutive `ssh -A` logins from a Mac running 1Password: each time, `ddev auth ssh` listed the forwarded keys and `ddev exec ssh -T git@github.com` authenticated, with no restart in between.

Limits: the most recent `ssh -A` login wins, and after it ends, containers can't reach an agent until the next login. `systemctl --user set-environment` doesn't survive a reboot; `~/.config/environment.d/` might, untested.
