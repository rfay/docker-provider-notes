# Colima on Linux

**Tested:** Colima with Lima 2.2.1 and QEMU 11.1.2, Ubuntu 26.04 amd64 on EC2 with KVM (`vmType: qemu`, `mountType: sshfs`), and Ubuntu 26.04 arm64 in Parallels without KVM, October 2026.

Unsupported by DDEV. It runs Docker in a QEMU VM, which adds overhead over docker-ce with no benefit on Linux.

## Setup

- **KVM is required in practice.** Without `/dev/kvm`, as in an arm64 Parallels VM on a Mac, QEMU emulates the CPU and Colima is too slow to use.
- Colima creates and selects the `colima` Docker context. `colima stop` can leave the default context selected, and a failed start may not create the context at all; `DOCKER_HOST=unix://$HOME/.config/colima/default/docker.sock` works meanwhile.

## Usage problems

- **Ports 80 and 443 don't reach the host.** See [Privileged ports](../topics/privileged-ports.md). Fix with `net.ipv4.ip_unprivileged_port_start=80`, or move DDEV's router to high ports.
- **QEMU crash leaves Colima "Broken".** QEMU once aborted with `net/net.c:2172: net_fill_rstate: Assertion 'size == 0' failed`. Lima's host agent logged that it was shutting down but stayed alive holding Docker's socket, so `docker ps` and `ddev start` hung, and `colima list` showed `Broken`. Four `limactl usernet` daemons had built up from earlier starts. Recovery:

  ```bash
  pkill -f "^/home/linuxbrew/.linuxbrew/Cellar/lima/[^ ]*/bin/limactl (hostagent|usernet)"
  colima stop --force && colima start
  pgrep -af "limactl usernet"    # expect one
  ```

  Don't use `pkill -f "limactl hostagent"` from an `ssh host '...'` command: the pattern matches the remote shell's own command line.

## SSH agent

Colima forwards the agent of the shell that ran `colima start`, only with `colima start --ssh-agent` or `forwardAgent: true` in `~/.config/colima/default/colima.yaml`. Inside the VM it links `/run/host-services/ssh-auth.sock` to the forwarded socket, and `ssh_agent_upstream=host` uses that.

- **From an `ssh -A` login:** `colima stop && colima start` from that login, then `ddev auth ssh`. Tested: it listed the 1Password keys forwarded from a Mac, and `ddev exec ssh -T git@github.com` authenticated.
- **After that login ends,** the forwarded agent is gone. `ddev auth ssh` fails immediately with "communication with agent failed" and suggests restarting Colima; it doesn't hang the way Docker Desktop does.
- **Started without an agent,** Docker creates `/run/host-services/ssh-auth.sock` in the VM as an empty root-owned directory when `ddev-ssh-agent` mounts it. `ddev auth ssh` then reports "communication with agent failed". Restart Colima with `--ssh-agent`.
- **Colima's link step can fail.** On arm64 without KVM, `colima start --ssh-agent` failed with `ln: failed to create symbolic link '/run/host-services/ssh-auth.sock': No such file or directory`, because `/run/host-services` didn't exist yet, and Colima reported the VM as degraded. Creating the link by hand worked: `colima ssh -- sh -c 'sudo mkdir -p /run/host-services && sudo ln -sf $SSH_AUTH_SOCK /run/host-services/ssh-auth.sock'`. It worked on amd64 with KVM.
