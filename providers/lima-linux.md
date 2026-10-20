# Lima on Linux

**Tested:** Lima 2.2.1, QEMU 11.1.2, Ubuntu 26.04 amd64 on EC2 with KVM, October 2026.

Unsupported by DDEV, like [Colima on Linux](colima-linux.md), which is built on Lima.

## Setup

The macOS recipe in DDEV's docs uses `--vm-type=vz --mount-type=virtiofs`, which are macOS-only or need extra packages on Linux. On Linux, use the **rootful** template:

```bash
limactl create --name=default --mount-writable --memory=6 template:docker-rootful
limactl start default
docker context create lima-default --docker "host=unix://$HOME/.lima/default/sock/docker.sock"
docker context use lima-default
```

`template:docker` (rootless Docker) with Lima's default 9p mount breaks DDEV: the web container can't write to the project, so `ddev start` fails in a `composer install` post-start hook with `Permission denied`. See [the results below](#templates-and-mount-types) and [File sharing and ownership](../topics/file-sharing.md).

- **Ports 80 and 443** need `net.ipv4.ip_unprivileged_port_start=80`; see [Privileged ports](../topics/privileged-ports.md).
- `--mount-type=virtiofs` needs `virtiofsd` on the host (`sudo apt install virtiofsd`). QEMU then backs all VM memory with `/dev/shm`, so a 6 GB VM uses 6 GB of `/dev/shm`, which defaults to half of host RAM.
- The VM's home directory is `/home/<user>.guest`; the host home is mounted at its usual path.
- `limactl list` shows `VMTYPE qemu` for every mount type. To see the mount type, run `limactl shell --workdir / default sh -c 'mount | grep /home'`.
- `limactl shell` changes into the current host directory. If the mount is hung, run it with `--workdir /`.

## Templates and mount types

Results from [scripts/lima-perm.sh](../scripts/lima-perm.sh): d11 (Drupal 11) project, `ddev start` with a `composer install` post-start hook, then a write test and `find vendor -type f` (13,615 files) from the web container.

| Template | Mount | `ddev start` | Container sees project as | Container write | `find vendor` |
| --- | --- | --- | --- | --- | --- |
| docker-rootful | 9p (default) | ok, 86s | 1001:1002 | ok | 4.1s |
| docker (rootless) | 9p (default) | **fails** (`composer install`) | 0:65534 | **denied** | 4.0s |
| docker-rootful | reverse-sshfs | ok, 84s | 1001:1002 | ok | 3.5s |
| docker (rootless) | reverse-sshfs | ok, 81s | 0:65534 | ok | 3.3s |
| docker-rootful | virtiofs | ok, 79s | 1001:1002 | ok | **1.2s** |
| docker (rootless) | virtiofs | **hung** | n/a | n/a | n/a |

The rootless virtiofs VM stopped responding during `ddev start`: `docker ps` and `limactl shell` hung, then SSH into the VM failed. `/dev/shm` was 81% full. Cause not determined. QEMU and `virtiofsd` survived `limactl stop -f` and had to be killed.

## SSH agent

Lima forwards the agent of the shell that ran `limactl start`, when the instance has `ssh.forwardAgent: true`. Set it at creation with `--set '.ssh.forwardAgent=true'`, or later with `limactl edit <instance> --set .ssh.forwardAgent=true`.

DDEV finds the forwarded socket with `limactl shell <instance> printenv SSH_AUTH_SOCK`, such as `/home/rfay.guest/.ssh/agent/s.*.sshd.*`. The path changes when the VM restarts.

Tested from an `ssh -A` login with 1Password forwarded from a Mac, rootful template: `ddev auth ssh` listed the forwarded keys and `ddev exec ssh -T git@github.com` authenticated. With rootless Docker and 9p, the agent worked too; only file writes failed.
