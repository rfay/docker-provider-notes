# SSH Agents in DDEV Containers

**Tested:** DDEV with [ddev/ddev#8963](https://github.com/ddev/ddev/pull/8963), October 2026.

## How DDEV relays an agent

By default `ddev-ssh-agent` runs its own agent, and `ddev auth ssh` adds key files to it. With `ddev config global --ssh-agent-upstream=<value>`, `ddev-ssh-agent` relays to an existing agent instead, and `ddev auth ssh` only lists the keys containers can use.

| `ssh_agent_upstream` | Socket DDEV relays to |
| --- | --- |
| `""` (default) | None; DDEV's own agent |
| `host` | On Docker Desktop, OrbStack, and Colima: `/run/host-services/ssh-auth.sock` inside the VM. On Lima: the VM's forwarded `SSH_AUTH_SOCK`, found with `limactl shell <instance> printenv SSH_AUTH_SOCK`. Otherwise: `$SSH_AUTH_SOCK` from the shell running `ddev` |
| An absolute path | That socket on the Docker host |

Details that matter when debugging:

- **Directory mount.** For a host socket, DDEV mounts the socket's whole directory into `ddev-ssh-agent`, so a recreated socket is still reachable. Keep agent sockets in their own directory, not `~/.ssh` or `~`. A provider's VM socket is mounted as a single file instead.
- **Symlinks.** DDEV resolves a symlinked socket, such as VS Code Remote's `/tmp/vscode-ssh-auth-sock-*`, and mounts the target's directory. A symlink whose target directory is gone is reported as stale ("an agent socket that no longer exists"). If the target directory still exists, DDEV treats the agent as not started yet and relays anyway.
- **Listening check.** Before relaying to a host socket, DDEV dials it to check that an agent is listening. It skips the check for sockets inside a provider's VM, which the host can't dial.
- **Timeout.** `ddev auth ssh` runs `timeout 120 ssh-add -l` in `ddev-ssh-agent`. It prints a waiting notice after 5 seconds, because a locked 1Password can be waiting for the user, and fails after 2 minutes.

## Forwarded agents (`ssh -A`)

Each `ssh -A` login gets a new socket, under `~/.ssh/agent/` with OpenSSH 10.1 and later, or `/tmp/ssh-*/` before that. The socket disappears when the login ends.

- **docker-ce:** DDEV reads `$SSH_AUTH_SOCK` from the current shell, so run `ddev auth ssh` again after logging in again.
- **Providers that capture the agent at startup** (Docker Desktop, Colima, Lima) keep using the socket from when they started. See each provider page. For Docker Desktop, a fixed symlink path updated from `~/.ssh/rc` avoids restarts; see [docker-desktop-linux.md](../providers/docker-desktop-linux.md#ssh-agent).

## Quick checks

```bash
ssh-add -l                                    # the agent in this shell
ddev auth ssh                                 # the agent containers get
ddev exec ssh -T git@github.com               # signing from the web container
docker exec ddev-ssh-agent ssh-add -l         # the relay itself
```

If `ssh-add -l` and `ddev auth ssh` list different keys, the provider is relaying a different agent than your shell's. That's normal for providers that capture the agent at startup.
