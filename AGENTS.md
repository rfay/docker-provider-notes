# AGENTS.md

Guidance for AI agents adding to or using these notes. Read [README.md](README.md) for the layout and [HANDOFF.md](HANDOFF.md) for the test machines.

## What belongs here

Findings about Docker providers as DDEV sees them: setup recipes, odd behavior, failure modes, and how each provider gets an SSH agent into containers. Detail too obscure or short-lived for the [DDEV docs](https://docs.ddev.com/) goes here, including unsupported setups. Changes to DDEV itself go in [ddev/ddev](https://github.com/ddev/ddev); link the issue or PR from the finding.

## Writing a finding

- Put it on the provider page under `providers/<provider>-<os>.md`, or in `topics/` when it spans providers. Add new pages to the README tables.
- Start every page with a **Tested** line: provider and engine versions, host OS and architecture, virtualization (KVM or not), and the month. Update it when you retest.
- Every provider page has an **SSH agent** section, even if it only says what isn't supported.
- Say what you observed, separately from what you infer. Mark untested or inferred claims as such ("inferred", "untested", "not determined"). A failed reproduction is a finding too; record what you tried.
- Quote the exact error text and the log file it came from, so the page can be found by searching for the error.
- Keep scripts that produced results in `scripts/`, with a usage comment, and link them from the results.

## Running tests on the machines

- **Check the Docker context first** (`docker context show`). Several providers coexist on the test machines, and each switches the context when it starts. DDEV follows the active context.
- **State the plan before running,** then report outcomes against it.
- **Run one VM-based provider at a time.** Colima, Lima, and Docker Desktop each run a QEMU VM and compete for memory; Lima with virtiofs keeps all VM memory in `/dev/shm`.
- **Don't `pkill -f` a pattern that appears in your own command.** Over `ssh host '...'`, the remote shell's command line contains the pattern, so `pkill -f "limactl hostagent"` kills your own session. Anchor the pattern to the binary path, such as `pkill -f "^/home/linuxbrew/.linuxbrew/Cellar/lima/[^ ]*/bin/limactl hostagent"`.
- **`ssh -A` sockets are per login.** A test that needs the forwarded agent must run inside one `ssh -A` session, including any provider restart. When that session ends, the socket is gone.
- **Collect evidence before restarting a hung provider.** For Docker Desktop, `com.docker.diagnose gather`; see [topics/docker-desktop-deadlocks.md](topics/docker-desktop-deadlocks.md).
- **Clean up:** power off DDEV projects, stop VMs you started, remove copied binaries and scratch files, and restore any global setting you changed (`ssh_agent_upstream`, systemd or launchd `SSH_AUTH_SOCK`). Record anything you leave in place in [HANDOFF.md](HANDOFF.md).

## Repository rules

- Never push. Commit locally when asked; the owner pushes.
- No secrets, private keys, or account IDs beyond what is already in HANDOFF.md.
- Plain Markdown; links relative within the repository.
