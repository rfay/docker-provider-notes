# WSL2

**Tested:** not retested here; from DDEV's docs, October 2026.

## SSH agent

Windows agents, such as 1Password and the Windows OpenSSH agent, listen on a named pipe that Docker can't pass to a Linux container, so `ssh_agent_upstream` doesn't work from native Windows. In WSL2, bridge the pipe to a Unix socket with `socat` and [`npiperelay`](https://github.com/albertony/npiperelay), then point DDEV at the socket. This works with Docker Desktop's WSL integration and with Docker installed in WSL2. Docker Desktop on Windows doesn't forward an agent of its own; from WSL2 it binds sockets from the user's distro, so `$SSH_AUTH_SOCK` works there.

DDEV's docs have the full `socat` recipe under "Using an Existing SSH Agent".
