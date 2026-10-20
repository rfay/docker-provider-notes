#!/bin/bash
# Changes files in a bind-mounted directory, checking after each round that
# `docker run` still starts a container. Used to hunt Docker Desktop's
# container-start deadlock.
# Usage: file-churn-repro.sh <host-dir> [rounds]
dir=$1; rounds=${2:-20}
for r in $(seq 1 "$rounds"); do
  for i in $(seq 1 50); do echo "$r" > "$dir/f$i.txt"; done
  rm -f "$dir"/f*.txt
  mkdir -p "$dir/sub$r" && touch "$dir/sub$r/x" && rm -rf "$dir/sub$r"
  start=$(date +%s.%N)
  if ! timeout -k 2 20 docker run --rm busybox true; then
    echo "round $r: docker run HUNG"; exit 1
  fi
  printf "round %d: run ok %.2fs\n" "$r" "$(echo "$(date +%s.%N) - $start" | bc)"
done
echo "no hang after $rounds rounds"
