# Docker Desktop Deadlocks

**Tested:** Docker Desktop 4.96.0 for Linux, Ubuntu 26.04 amd64, October 2026. The same stack is reported on Windows.

## Symptom

- `docker run` and `docker start` hang forever; the container stays in `Created`
- `docker ps`, `docker exec`, `docker inspect`, and `docker logs` keep working
- Project sites may stop answering
- `ddev poweroff` and `ddev start` hang, because they start helper containers

Only restarting Docker Desktop recovers.

## What's stuck

A goroutine dump of the backend shows file sharing blocked:

```text
grpcfuse/volume.(*svr).recomputeWatches
  -> grpcfuse/volume.(*watch).Invalidate
  -> grpcfuse/pb.(*eventClient).Write        # gRPC call into the VM, no timeout, waiting minutes
apiproxy.(*containerStartRewriter).RequestRewrite
  -> grpcfuse/pb._VolumeShare_Add_Handler
  -> grpcfuse/volume.(*svr).recomputeWatchesSync   # every container start waits here
```

Every container start goes through `VolumeShare.Add`, even with no host mounts, so one stuck invalidation blocks them all. `docker ps` and `docker exec` don't use that path. The VM kernel showed no blocked tasks, so the part not answering is a user-space process in the VM.

Matches [docker/desktop-feedback#706](https://github.com/docker/desktop-feedback/issues/706) (open; Windows; Docker couldn't reproduce it as of 2026-10-15). Related: [docker/desktop-feedback#204](https://github.com/docker/desktop-feedback/issues/204).

## Trigger

Not determined. In testing:

- Two of three hangs started at the helper container `ddev poweroff` runs (`remove-project-merged-config`); one followed a hung `ddev auth ssh`
- They came 3 to 14 minutes after Docker Desktop started, with a person working interactively
- Not reproduced by: 20 rounds of file changes in a bind-mounted directory, with and without DDEV; three `ddev poweroff`/`ddev start` cycles with two projects and continuous curl traffic; a 7-minute hung agent request with container starts every 20 seconds

DDEV may raise the odds: each container start or stop makes Docker Desktop recompute its watches, and one `ddev start` runs about eight short-lived helper containers. DDEV also calls `ContainerStart` with no timeout, so it hangs along with Docker.

## Capturing evidence

Before restarting Docker Desktop:

```bash
/opt/docker-desktop/bin/com.docker.diagnose gather ~/tmp/dd-diag.zip   # local only, no upload
unzip -q ~/tmp/dd-diag.zip -d ~/tmp/dd-diag
grep -n "recomputeWatches\|containerStartRewriter\|VolumeShare" ~/tmp/dd-diag/backend/stacks.log
```

The API timeline is in `~/.docker/desktop/log/host/monitor.log`. To list mutating calls with timestamps:

```bash
grep -E "(>>|<<) (POST|DELETE)" ~/.docker/desktop/log/host/monitor.log \
  | jq -Rr 'capture("\\] (?<j>.*)")?.j | fromjson? | [.time[11:23], .msg] | @tsv'
```

The first `>> POST /containers/<id>/start` with no matching `<<` is where it started.
