# Docker Provider Notes

Field notes on Docker providers as DDEV sees them: setup recipes, odd behavior, and how each one exposes an SSH agent to containers. This is the place for detail that is too obscure or too short-lived for the [DDEV docs](https://docs.ddev.com/), including setups DDEV doesn't support.

Every finding records what it was tested on and when, because providers change quickly. Treat anything older than a few releases as a lead to recheck, not a fact.

## Providers

| Provider | Host OS | DDEV support | Page |
| --- | --- | --- | --- |
| docker-ce | Linux | Supported, recommended | [docker-ce-linux.md](providers/docker-ce-linux.md) |
| Docker Desktop | Linux | Not recommended, untested in CI | [docker-desktop-linux.md](providers/docker-desktop-linux.md) |
| Docker Desktop | macOS | Supported | [docker-desktop-macos.md](providers/docker-desktop-macos.md) |
| OrbStack | macOS | Supported | [orbstack-macos.md](providers/orbstack-macos.md) |
| Colima | macOS | Supported | [colima-macos.md](providers/colima-macos.md) |
| Colima | Linux | Unsupported | [colima-linux.md](providers/colima-linux.md) |
| Lima | macOS | Supported | [lima-macos.md](providers/lima-macos.md) |
| Lima | Linux | Unsupported | [lima-linux.md](providers/lima-linux.md) |
| Rancher Desktop, Podman | macOS, Linux | Supported, with limits | [rancher-podman.md](providers/rancher-podman.md) |
| Docker Desktop or docker-ce | Windows WSL2 | Supported | [wsl2.md](providers/wsl2.md) |
| Docker Desktop | Windows, native | Supported | [docker-desktop-windows.md](providers/docker-desktop-windows.md) |

## Topics

- [SSH agents in DDEV containers](topics/ssh-agent.md): how `ssh_agent_upstream` works, and how each provider gets an agent into its VM
- [Docker Desktop deadlocks](topics/docker-desktop-deadlocks.md): container starts that hang forever, and how to capture evidence
- [Privileged ports in VM-based providers](topics/privileged-ports.md): why the router's ports 80 and 443 can silently fail to reach the host
- [File sharing and ownership](topics/file-sharing.md): 9p, virtiofs, and sshfs, with rootful and rootless Docker
- [External volumes and symlinked project roots](topics/external-volumes.md): projects on external drives or behind a symlink or junction, Mutagen, exFAT, and provider access to removable volumes (macOS and native Windows)

## Scripts

- [scripts/lima-perm.sh](scripts/lima-perm.sh): creates a Lima instance with a given template and mount type, then checks `ddev start`, container writes, ownership, and file-access speed
- [scripts/file-churn-repro.sh](scripts/file-churn-repro.sh): changes files in a bind-mounted directory and checks after each round that `docker run` still works
- [scripts/ddev-external-volume-check.sh](scripts/ddev-external-volume-check.sh): checks bind mounts, Mutagen sync, snapshot, export and import, import-files, and pull for a running DDEV project
- [scripts/ddev-external-volume-check.ps1](scripts/ddev-external-volume-check.ps1): the same kind of checks for one project on native Windows, in PowerShell
- [scripts/ddev-pull-check.ps1](scripts/ddev-pull-check.ps1) and [scripts/ddev-pull-check-provider.yaml](scripts/ddev-pull-check-provider.yaml): `ddev pull` with a local provider on native Windows

## Test machines

[HANDOFF.md](HANDOFF.md) explains how to start the EC2 machine that can run KVM, and what state each machine was left in. [AGENTS.md](AGENTS.md) has the rules for adding findings and running tests.

## Conventions

- Each page starts with a **Tested** line: versions, host, and date.
- "Unsupported" means DDEV doesn't test it and doesn't promise it works; notes here explain what happens anyway.
- Link the DDEV issue or PR where a finding came from, so the discussion can be found again.

## License

[Apache License 2.0](LICENSE)
