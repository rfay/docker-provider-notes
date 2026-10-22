# Docker Desktop on native Windows

**Tested:** Docker Desktop (version not recorded) with Docker Engine 29.9.2 and the WSL2 backend, WSL 3.0.3.0 (kernel 6.18.54.1), on Windows 11 Home 10.0.26200 arm64, in October 2026. DDEV was built from [ddev/ddev#8987](https://github.com/ddev/ddev/pull/8987) at commit 53e341d96 and run from PowerShell and from git-bash (not from inside a WSL2 distro). Not covered here: Docker in a WSL2 distro, which is [wsl2.md](wsl2.md).

## How host paths reach containers

Docker Desktop runs the Linux engine inside its own WSL2 distro, `docker-desktop`. A bind mount of a Windows path, such as `-v C:\Users\me\proj\.ddev:/mnt/ddev_config`, works only because that distro has the Windows drive mounted as a 9p `drvfs` filesystem. Docker translates `C:\...` to `/run/desktop/mnt/host/c/...`, and the engine reads it under `/tmp/docker-desktop-root/run/desktop/mnt/host/c`.

Observed in `/proc/mounts` of the `docker-desktop` distro: `C:\` was mounted at `/mnt/host/c`, `/run/desktop/mnt/host/c`, and `/tmp/docker-desktop-root/...` (observed), and no other drive was mounted. The "File sharing" list in Docker Desktop's settings doesn't apply to the WSL2 backend: `FilesharingDirectories` in `%APPDATA%\Docker\settings-store.json` was empty while C: worked.

DDEV uses bind mounts for `.ddev` (read-only, at `/mnt/ddev_config`) and for every `upload_dirs` entry, even with Mutagen on. Mutagen itself runs on the host and doesn't depend on any of this.

## External drives

### Observed: a USB drive is invisible to Docker

A USB flash drive (`Get-Disk` BusType USB, `Get-Volume` DriveType Removable) at `D:` was not mounted in any WSL distro: Ubuntu had no `/mnt/d`, and `docker-desktop` had no `/run/desktop/mnt/host/d`. This held after a reformat from exFAT to NTFS, `wsl --shutdown` followed by a Docker Desktop restart, a reboot, and adding the drive to Docker Desktop's file sharing. That WSL skips removable drives at startup is inferred; the Microsoft documentation wasn't checked.

Docker reports no error. A bind mount of a D: path gives an empty directory:

```text
PS> docker run --rm -v "D:\workspace\probe:/x" alpine ls -la /x
total 5
drwxr-xr-x    2 root     root          1024 ... .
drwxr-xr-x    1 root     root          4096 ... ..
```

The directory held `marker.txt`. Docker also created empty placeholder directories for missing source paths inside the VM, so `docker run -v "D:\workspace:/x"` listed directories that had been deleted from the real drive. A listing that doesn't match the drive is the sign that Docker is not reading it.

### Observed: what DDEV shows

`ddev start` succeeds and Mutagen reports `Watching for changes`, with the project's files in the container. Everything that depends on a bind mount fails:

- The site returns 403, and `ddev logs` shows `directory index of "/var/www/html/" is forbidden`. The nginx config comes from `/mnt/ddev_config`, which is empty.
- `ddev snapshot` fails with `cp: cannot create regular file '/mnt/ddev_config/.snapshot...': Permission denied`.
- `ddev exec ls /mnt/ddev_config` prints nothing.

`ddev export-db` still works, because it writes to the host through the CLI. `touch /mnt/ddev_config/x` reports `Read-only file system` on C: as well; the mount is read-only by design.

### Observed: mounting the drive by hand fixes it

Run as the Windows user, with the drive present:

```bash
wsl -d docker-desktop -u root -e sh -c 'for b in /run/desktop/mnt/host /tmp/docker-desktop-root/run/desktop/mnt/host /tmp/docker-desktop-root/mnt/host /mnt/host; do mkdir -p $b/d && mount -t drvfs D: $b/d -o metadata; done'
```

Mounting only `/run/desktop/mnt/host/d` was not enough: the container still saw an empty directory. After the other three, `docker run -v "D:\..."` listed the real files, and every DDEV check passed ([results](../topics/external-volumes.md#results-with-the-fix)).

The mounts last until WSL restarts (inferred; a restart wasn't tested). A permanent fix wasn't found. Untested ideas: a non-removable drive, a VHD on the internal disk, or `wsl --mount` for the physical disk.

An agent session was blocked from running the `mount` until the owner approved it, because it changes a shared WSL distro. Expect to ask.

## git-bash and PowerShell

- **Docker commands in git-bash:** MSYS rewrites `-v` paths. `docker run -v 'D:\workspace:/x' alpine ls /x` failed with `ls: X:/: No such file or directory`. Use PowerShell, or set `MSYS_NO_PATHCONV=1`. `ddev exec ls /var/www/html` from git-bash needs the same setting; otherwise the path becomes `C:/Program Files/Git/var/www/html`.
- **PowerShell scripts:** may be refused with "running scripts is disabled on this system". Run them with `powershell -NoProfile -ExecutionPolicy Bypass -File script.ps1`.
- **Working directory inside a link:** a script that is inside a junction when it deletes and recreates it gets `The directory name is invalid` from every later native command. Change directory first.
- **Native commands writing to stderr** show as `NativeCommandError` records in `powershell.exe` (Windows PowerShell). Redirect with `2>&1` and convert to strings, as the scripts do.

## ddev pull: default database import fails

On native Windows, `ddev pull <provider>` fails at the database import when the provider has no `db_import_command`, on any project, linked or not:

```text
Importing databases [C:\Users\rfay\tmp\xl\ctl\.ddev\.downloads\db.sql.gz]
Pull failed: failed to import database: exit status 1
stdout:
stderr: ERROR at line 1: Unknown command '\U'.
```

The cause, from reading the code (the fix below was not yet run): `importDatabaseBackup` in `pkg/ddevapp/provider.go` takes the database name with `path.Base(loc)`. The `path` package splits only on `/`, so a Windows path comes back whole, and the name becomes `C:\Users\rfay\tmp\xl\ctl\`. `ImportDB` puts it into `CREATE DATABASE IF NOT EXISTS <name>`, and the mysql client reads `\U` as a command. The line dates from [ddev/ddev#4426](https://github.com/ddev/ddev/pull/4426) and is still on `upstream/main`. The earlier report [ddev/ddev#8572](https://github.com/ddev/ddev/issues/8572), from Windows 11 with Git Bash, shows the same error and was closed as a MariaDB version mismatch; inferred, not confirmed, that it is this bug.

Workaround: give the provider a `db_import_command` that runs on the host, such as `gzip -dc "${DDEV_APPROOT}/.ddev/.downloads/db.sql.gz" | ddev mysql db`. See [scripts/ddev-pull-check.ps1](../scripts/ddev-pull-check.ps1) and its provider file.

## SSH agent

Not tested here. Native Windows agents (1Password, the Windows OpenSSH agent) use a named pipe that a Linux container can't use; see [wsl2.md](wsl2.md#ssh-agent) for the bridge through WSL2.
