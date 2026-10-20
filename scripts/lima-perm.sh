#!/bin/bash
# Creates Lima instance "default" from a template and mount type, then checks
# `ddev start`, container writes, ownership as the container sees it, and
# file-access speed in ~/workspace/d11. Deletes any existing "default" instance.
# Usage: lima-perm.sh <template> <mount-type>   e.g. docker-rootful virtiofs
tpl=$1; mt=$2; D=${DDEV:-ddev}   # set DDEV=/path/to/ddev to test another build
echo "=== $tpl + $mt"
(cd ~/workspace/d11 && timeout 120 $D poweroff >/dev/null 2>&1)
limactl stop default >/dev/null 2>&1; limactl delete default >/dev/null 2>&1
timeout 600 limactl create --tty=false --name=default --mount-writable --memory=6 --mount-type="$mt" template:"$tpl" >/dev/null 2>&1 || { echo "create failed"; exit 1; }
if ! timeout 900 limactl start --tty=false default > ~/tmp/lima-start.log 2>&1; then echo "start failed:"; grep -iE "error|fatal" ~/tmp/lima-start.log | tail -3 | cut -c1-200; exit 1; fi
docker context use lima-default >/dev/null
echo "docker: $(docker info --format '{{.SecurityOptions}}' | grep -o rootless || echo rootful)"
echo "vm mount: $(limactl shell default sh -c 'mount | grep " /home/rfay " | cut -d" " -f5,6' | cut -c1-80)"
cd ~/workspace/d11
s=$(date +%s); if timeout 900 $D start >/dev/null 2>&1; then echo "ddev start: ok $(( $(date +%s)-s ))s"; else echo "ddev start: FAILED $(( $(date +%s)-s ))s"; fi
$D exec 'echo "container view: $(stat -c "%u:%g" composer.json)"; touch vendor/drupal/x 2>/dev/null && echo "container write: ok" || echo "container write: DENIED"; rm -f vendor/drupal/x' 2>&1 | grep container
s=$(date +%s.%N); n=$($D exec 'find vendor -type f | wc -l' 2>/dev/null); echo "find vendor ($n files): $(echo "$(date +%s.%N) - $s" | bc | cut -c1-5)s"
echo "host-side new file owner: $($D exec 'touch .perm-test' >/dev/null 2>&1; stat -c %U:%G .perm-test 2>/dev/null; rm -f .perm-test)"
