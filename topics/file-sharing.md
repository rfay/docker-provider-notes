# File Sharing and Ownership

**Tested:** Lima 2.2.1 on Ubuntu 26.04 amd64, October 2026. macOS behavior is inferred, not retested.

## What decides whether a container can write

Two things combine: who the VM thinks owns the files, and whether the VM's kernel or the host checks permissions.

- **Rootful Docker** runs containers with the VM's uids unchanged. DDEV runs the web container as the host user's uid, Lima creates the VM user with that same uid, and the mount shows host ownership, so writes work with any mount type.
- **Rootless Docker** maps the VM user's uid to root inside containers, and container uids to subordinate uids in the VM (100000 and up). Inside the container, the project shows as `0:65534`, and the web container's writes reach the VM from a subordinate uid.

Whether that subordinate uid can write depends on the mount:

| Mount | Who checks permissions | Rootless Docker writes |
| --- | --- | --- |
| 9p (Lima's default on Linux) | The VM kernel, using the host's uids | Denied |
| reverse-sshfs | The host's SFTP server, running as the user | Allowed |
| virtiofs on macOS (`vz`) | macOS, as the user | Allowed (inferred) |
| virtiofs on Linux (QEMU + `virtiofsd`) | `virtiofsd`, as the user | Not determined: the VM hung |

So rootless Docker works where the host does the file I/O as the user, and fails where the VM enforces ownership. That's why DDEV's macOS Lima recipe uses rootless Docker without trouble, while the same template on Linux with 9p breaks.

DDEV's `IsDockerRootless()` deliberately excludes Lima, so DDEV applies none of its rootless adjustments there.

## Speed

`find vendor -type f` over 13,615 files from the web container: virtiofs 1.2s, reverse-sshfs 3.3 to 3.5s, 9p 4.0 to 4.1s. See [lima-linux.md](../providers/lima-linux.md#templates-and-mount-types) for the full table.
