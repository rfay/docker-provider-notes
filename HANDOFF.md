# HANDOFF

How to bring up the test machines and what state they were left in. Last updated 2026-10-20.

## EC2 test machine (amd64, KVM)

The only EC2 setup found that can run KVM, and therefore Docker Desktop for Linux, Colima, and Lima at usable speed.

| | |
| --- | --- |
| Instance | `i-0fdd225f0b05a2c7e`, us-east-1 (AZ us-east-1e) |
| Type | `m7i.xlarge` (4 vCPU, 16 GiB), originally `t3.xlarge` |
| OS | Ubuntu 26.04.1 LTS amd64 |
| User | `rfay` (uid 1001) |
| Public IP and DNS name | Change at every stop/start; look them up (below) |

A second instance, `i-01949df2da9fdf709` (`t4g.large`, arm64), works for docker-ce but can't run KVM: AWS offers nested virtualization only on some Intel types.

### Starting it

```bash
aws ec2 start-instances --region us-east-1 --instance-ids i-0fdd225f0b05a2c7e
aws ec2 describe-instances --region us-east-1 --instance-ids i-0fdd225f0b05a2c7e \
  --query 'Reservations[0].Instances[0].PublicDnsName' --output text
ssh -A rfay@<that name>
```

A `Host` entry in `~/.ssh/config` with the current `HostName` saves retyping it. An Elastic IP would keep the address fixed, and is free while attached to a running instance.

First boot after a start can take about 4 minutes, and status checks may show `impaired` meanwhile. `aws ec2 get-console-output --region us-east-1 --instance-id i-0fdd225f0b05a2c7e --latest --output text` shows the boot; it recovered on its own. An SSM agent error in that log is harmless (no IAM role).

Stop it when done; a stopped instance costs only its EBS storage. `m7i.xlarge` is about $0.20/hour on demand, about $147/month if left running.

### Nested virtualization

Available on non-metal EC2 since 2026-02-12, for C7i, M7i, R7i, the 8i families, and I7i (Intel only; not t3, not Graviton). It's a CPU option, off by default, and changing the instance type doesn't turn it on. With the instance stopped:

```bash
aws ec2 modify-instance-cpu-options --region us-east-1 \
  --instance-id i-0fdd225f0b05a2c7e \
  --core-count 2 --threads-per-core 2 \
  --nested-virtualization enabled
```

Check after boot: `lsmod | grep kvm` (expect `kvm_intel`), `ls -l /dev/kvm`, `sudo kvm-ok`. The user must be in the `kvm` group.

Docker doesn't support Docker Desktop in nested virtualization. It worked here, apart from the [deadlocks](topics/docker-desktop-deadlocks.md), which Docker also sees on bare hardware.

References: [AWS nested virtualization](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html), [Docker Desktop Linux requirements](https://docs.docker.com/desktop/setup/install/linux/).

### Desktop access

Docker Desktop needs a graphical session. Use SSH tunnels so no security-group ports open:

- **NoMachine** (works): `ssh -L 4000:localhost:4000 rfay@<host>`, then connect the NoMachine client to `localhost:4000`.
- **xrdp** (unresolved): `ssh -L 3390:localhost:3389 rfay@<host>`, then an RDP client to `localhost:3390`. It showed a blank desktop and disconnected, because `gnome-session` exits within a second, probably since Ubuntu 26.04's GNOME is Wayland-only. Untested fix: `sudo apt install xfce4 xfce4-goodies`, `echo xfce4-session > ~/.xsession`, `sudo systemctl restart xrdp`.

### What's installed

| Provider | Docker context | Notes |
| --- | --- | --- |
| docker-ce | `default` | Installed |
| Docker Desktop 4.96.0 | `desktop-linux` | `systemctl --user start docker-desktop`. Installing the `.deb` first failed on `qemu-system-x86`, `pass`, and `uidmap` being "not installable"; `sudo apt update` and the `universe` component are the first things to check |
| Colima (Homebrew) | `colima` | Profile `default`: QEMU, sshfs, `forwardAgent: true` |
| Lima 2.2.1 (Homebrew) | `lima-default` | Instance `default`. Use `template:docker-rootful` on Linux; see [lima-linux.md](providers/lima-linux.md) |

Homebrew's QEMU (`/home/linuxbrew/.linuxbrew/bin/qemu-system-x86_64`) serves Colima and Lima; Docker Desktop uses the system QEMU. `virtiofsd` is installed for Lima's `--mount-type=virtiofs`.

Projects: `~/workspace/d11` (Drupal 11, `composer install` as a post-start hook, useful for catching write-permission problems) and `~/workspace/junk` (PHP).

### State left on 2026-10-20

- **Docker context:** `lima-default`. Switch with `docker context use <name>` before testing anything else.
- **Lima:** instance `default` is stopped, and was last created as rootless Docker with 9p, which breaks DDEV. Recreate with `scripts/lima-perm.sh docker-rootful virtiofs` or the recipe in [lima-linux.md](providers/lima-linux.md).
- **Colima:** stopped.
- **docker-ce:** enabled but not running (`sudo systemctl start docker`). The Docker Desktop docs suggest stopping docker-ce while Docker Desktop runs.
- **Docker Desktop:** not running. Its systemd user environment has `SSH_AUTH_SOCK=$HOME/.ssh-agent-forward/agent.sock`, the fixed-path setup from [docker-desktop-linux.md](providers/docker-desktop-linux.md#ssh-agent); a reboot clears it.
- **`~/.ssh/rc`:** points `~/.ssh-agent-forward/agent.sock` at each `ssh -A` login's socket, and runs `xauth` for X11 forwarding. Remove it to go back to sshd's default X11 handling.
- **`net.ipv4.ip_unprivileged_port_start`:** 80, from `/etc/sysctl.d/99-lima-ports.conf`, so Colima and Lima can forward the router's ports 80 and 443. It persists across reboots.
- **DDEV global config:** `ssh_agent_upstream: host`.
- **Agents on the machine:** the GNOME keyring agent at `/run/user/1001/gcr/ssh` holds one key (`rfay@ip-172-30-4-46`), useful when no forwarded agent is around.
- **Files:** `~/tmp/dd-diag.zip` and `~/tmp/dd-diag2.zip` (Docker Desktop deadlock diagnostics), `~/tmp/lima-perm.sh`.

### Getting a quick baseline

```bash
sudo systemctl start docker
docker context use default && docker run --rm busybox echo ok   # docker-ce
cd ~/workspace/d11 && ddev start && ddev auth ssh
curl -sk -o /dev/null -w '%{http_code}\n' https://d11.ddev.site
```

## ub-2604 (arm64, no KVM)

Ubuntu 26.04 arm64 in Parallels on a Mac, reached as `ssh ub-2604` while the VM is running. No `/dev/kvm`, so Colima and Lima fall back to software emulation and are too slow to use. Good for docker-ce on arm64.

- docker-ce was not enabled at boot on 2026-10-20: `sudo systemctl enable --now docker`.
- The DDEV checkout is in `~/workspace/ddev`, often on a working branch; use `git worktree add` to test another branch without disturbing it.
- The login profile sets `SSH_AUTH_SOCK=~/.1password-agent.sock`, in the home directory, so with `ssh_agent_upstream=host` DDEV mounts all of `~` into `ddev-ssh-agent`.
