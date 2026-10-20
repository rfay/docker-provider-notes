# Colima on macOS

**Tested:** not retested here; from DDEV's docs, October 2026.

## SSH agent

Start Colima with `colima start --ssh-agent`, or set `forwardAgent: true` in its config. It forwards the agent of the shell that started it and links it to `/run/host-services/ssh-auth.sock` in the VM, which `ssh_agent_upstream=host` uses. Colima ignores `IdentityAgent` in `~/.ssh/config`; to use 1Password or another agent, point the system-wide `SSH_AUTH_SOCK` at it.

Without `--ssh-agent`, Docker creates `/run/host-services/ssh-auth.sock` in the VM as an empty directory, and `ddev auth ssh` reports "communication with agent failed" with a hint to restart Colima. After `colima stop` and `colima start` with a container still using the socket, it can become a directory containing a symlink ([abiosoft/colima#942](https://github.com/abiosoft/colima/issues/942)); stop the containers and restart Colima.

See [colima-linux.md](colima-linux.md) for behavior tested on Linux, most of which comes from Colima itself.
