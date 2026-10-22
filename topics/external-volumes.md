# External Volumes and Symlinked Project Roots

**Tested:** OrbStack 2.2.4 with Docker Engine 29.8.2, on macOS 27.0.1 arm64, in October 2026. The DDEV binary was built from [ddev/ddev#8987](https://github.com/ddev/ddev/pull/8987) at commit 53e341d96, with Mutagen 0.18.1. The external drive was a USB flash drive, first formatted exFAT and then APFS. Windows and WSL2 are not tested yet.

This page covers DDEV projects whose files are on an external drive, and projects whose root directory is a symlink or a Windows junction. The motivating report is [ddev/ddev#8924](https://github.com/ddev/ddev/issues/8924). There, a user moved projects to an external APFS drive and left a symlink at each old path.

## Where the problems come from

Two separate parts of DDEV touch the host files, and each can fail on its own:

- **Mutagen** syncs the project into a Docker volume. It runs on the host, so the Docker provider's file sharing doesn't affect it. Mutagen refuses a sync root whose last path component is a link. In its source, `pkg/synchronization/core/scan.go` opens the root without following a link at that position. A link higher up in the path is fine.
- **Bind mounts** still carry `.ddev` (at `/mnt/ddev_config`) and every `upload_dirs` entry, even when Mutagen is on. The provider's VM has to be able to see these host paths. With `performance_mode: none`, the whole project is a bind mount.

## Symlinked project root

### Observed: a release without the fix (v1.25.4)

With Mutagen on, a project whose root is a symlink starts and reports success. The site then serves an empty docroot. `ddev start` prints this:

```text
Mutagen sync session <name> has status 'failing' ... lastError:alpha scan error: unable to open synchronization root: too many levels of symbolic links
```

`ddev mutagen st -l` shows the same error under "Last error". With `performance_mode: none`, the same project works.

Two workarounds work without the fix:

- Put the symlink one directory higher, for example `~/Development -> /Volumes/Work/Development`, so the project root itself is a real directory. The reporter confirmed this.
- Unlist the project and run DDEV from the real path. Then every DDEV command run from the symlink path is refused with "project root is already set".

### Observed: with the fix (ddev/ddev#8987)

DDEV gives Mutagen the link's target, and `ddev mutagen st -l` shows that target as the host URL. Two arrangements were tested on macOS with OrbStack:

- **A:** the files are on the internal disk and the symlink is on the external drive.
- **B:** the files are on the external drive and the symlink is on the internal disk.

Both passed every check in [scripts/ddev-external-volume-check.sh](../scripts/ddev-external-volume-check.sh):

- The `upload_dirs` bind mount works in both directions.
- Mutagen syncs a new host file into the container.
- `ddev snapshot` writes to the host, and `ddev snapshot restore` works.
- `ddev export-db` and `ddev import-db` work.
- `ddev import-files` works.
- `ddev pull` works with a custom provider that writes into `.ddev/.downloads` from the web container.
- `ddev utility mutagen-diagnose` reports correctly.

A sync session keeps the host path it was created with. The fix recreates the session and its Mutagen volume when that path is no longer the link's target. These cases were observed:

- **The link is pointed at a local copy of the project:** the session is recreated, and the local copy is served.
- **The link is pointed back at the drive:** the session is recreated, and the drive's copy is served. None of the local copy's changes leaked into it.
- **A failing session left by v1.25.4:** the first `ddev start` with the fix repairs it. No `ddev mutagen reset` is needed.
- **The drive is missing,** tested with an APFS disk image as the stand-in: `ddev start` fails at once with "could not find requested project", because `.ddev/config.yaml` is on the drive. Nothing is recreated or removed.

## Filesystem: use APFS, not exFAT

Observed with a project directly on an exFAT drive, with no symlink and `performance_mode: none`: `ddev start` fails while it builds the project images.

```text
failed to read dockerfile: error from sender: failed to xattr /Volumes/EFI-SYSTEM/workspace/bmdirect/.ddev/.dbimageBuild/._Dockerfile: operation not permitted
```

On exFAT, macOS writes an AppleDouble `._*` file beside every file to hold its extended attributes. These files also make DDEV list every `._*` file under `.ddev` as custom configuration. They also trigger warnings such as `unable to clean up directory .webimageBuild`.

The same drive, reformatted as APFS, works. FAT32 is untested; it probably behaves like exFAT (inferred).

## Provider access to the drive

### OrbStack on macOS (observed)

After the drive was reformatted as APFS, OrbStack still couldn't read anything on it:

```text
$ docker run --rm -v /Volumes/EFI-SYSTEM/bmreal:/x busybox ls /x
ls: can't open '/x': Operation not permitted
```

In DDEV, the web container exits at startup. `docker logs ddev-<project>-web` shows this:

```text
cp: cannot access '/mnt/ddev_config/nginx_full': Operation not permitted
```

The cause is macOS privacy control: OrbStack had no access to removable volumes. In System Settings → Privacy & Security → Files & Folders, OrbStack's entry showed only "Network Volumes" and a 1Password item, with no Removable Volumes switch. Access worked after the user changed the setting and restarted OrbStack.

A Removable Volumes switch shows up only after an app has asked for access. If it's missing, two approaches should work (inferred):

- Add OrbStack under Full Disk Access.
- Run `tccutil reset SystemPolicyRemovableVolumes dev.kdrag0n.MacVirt`, restart OrbStack, and access the drive again so macOS asks.

An APFS disk image made with `hdiutil create -fs APFS` and mounted under `/Volumes` did not need this permission. So a disk image doesn't stand in for a real drive when you test provider access.

### Other providers (not tested)

The fix differs by provider. Each provider that runs a VM decides which host paths the VM can see. These are defaults as we understand them, none of them checked:

- **Docker Desktop for Mac:** the File Sharing list includes `/Volumes` by default. macOS may still need to grant removable-volume access.
- **Colima, Lima, and Rancher Desktop** (which uses Lima): only the home directory is shared by default. A path under `/Volumes/...` needs an extra mount in the VM configuration.
- **Podman machine:** `$HOME`, `/private`, and `/var/folders` are shared by default. A path under `/Volumes/...` needs an extra mount.

Record results here when you test one of these, with the exact error text.

## Windows

Not tested yet. Points to cover:

- Windows has two kinds of directory link: a symbolic link (`mklink /D`, which needs Developer Mode or an administrator shell) and a junction (`mklink /J`). Mutagen refuses both as a sync root. Since Go 1.23, Go reports a junction as an irregular file rather than a symlink, so ddev/ddev#8987 handles it separately.
- Remove a link with `cmd /c rmdir <link>`. Using `Remove-Item` on a junction can delete the files in the target.
- The Windows test procedure (W1 to W7) is in the [ddev/ddev#8987 description](https://github.com/ddev/ddev/pull/8987).
- Still to do: an external drive with a drive letter, and Docker Desktop file sharing for it.
