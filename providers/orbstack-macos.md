# OrbStack on macOS

**Tested:** not retested here; from DDEV's docs, October 2026.

## SSH agent

OrbStack provides an agent at `/run/host-services/ssh-auth.sock` with nothing extra to set up. It uses the agent named by `IdentityAgent` in `~/.ssh/config`, such as 1Password, and otherwise the macOS agent. Restart OrbStack after changing `~/.ssh/config`.

## External drives

OrbStack needs macOS removable-volume access before containers can read a project on an external drive; without it, bind mounts fail with `Operation not permitted`. Tested October 2026 with OrbStack 2.2.4. See [External volumes and symlinked project roots](../topics/external-volumes.md#orbstack-on-macos-observed).
