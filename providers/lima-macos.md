# Lima on macOS

**Tested:** not retested here; from DDEV's docs, October 2026.

## Setup

DDEV's recipe:

```bash
limactl create --name=default --vm-type=vz --mount-type=virtiofs --mount-writable --memory=6 --cpus=4 --disk=100 template:docker
```

`template:docker` is rootless Docker. It works on macOS because Apple's virtiofs does file I/O as the Mac user; the same template with 9p on Linux doesn't. See [File sharing and ownership](../topics/file-sharing.md).

## SSH agent

Enable forwarding once: `limactl edit <instance> --set .ssh.forwardAgent=true`. Lima forwards the agent of the shell that ran `limactl start`; DDEV finds the VM-side socket with `limactl shell <instance> printenv SSH_AUTH_SOCK`. Lima ignores `IdentityAgent` in `~/.ssh/config`; to use 1Password or another agent, point the system-wide `SSH_AUTH_SOCK` at it.
