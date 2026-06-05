#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# tool/cloud_rent_arm64_gcp.sh — one-off GCP Tau T2A (arm64 / Ampere Altra)
# rent helper for the SELFHOST-NEXT native linux-arm64 self-emit lane.
#
# WHY a one-off script (not a full `hexa cloud` provider adapter):
#   `hexa cloud` providers = {vast, runpod}, both 100% x86_64 (no arm64 inventory
#   — see domains/SELFHOST-NEXT.log.md lane-B sweep). The native arm64 self-emit
#   needs a ≥16 GiB aarch64-linux host the wired providers cannot supply. GCP T2A
#   (t2a-standard-4 = 4 vCPU/16 GiB, t2a-standard-8 = 8 vCPU/32 GiB; arm64) is the
#   cheapest arm64 path on EXISTING creds. A full provider adapter is logged as
#   SELFHOST-NEXT follow-up; this script is the minimal thing that UNBLOCKS the run.
#
# CREDS: GCP auth comes from the ambient `gcloud` config (account + project), the
# same surface the secret store's gcp.project / gcp.access_token back. NO secret is
# written into any file or echoed into a log by this script.
#
# Usage:
#   tool/cloud_rent_arm64_gcp.sh up    [NAME] [MACHINE] [ZONE]   # create + wait SSH
#   tool/cloud_rent_arm64_gcp.sh ssh   NAME [ZONE] -- <cmd...>   # run a remote cmd
#   tool/cloud_rent_arm64_gcp.sh push  NAME SRC DEST [ZONE]      # scp local->remote
#   tool/cloud_rent_arm64_gcp.sh pull  NAME SRC DEST [ZONE]      # scp remote->local
#   tool/cloud_rent_arm64_gcp.sh down  NAME [ZONE]               # DELETE (teardown)
#
# Defaults: MACHINE=t2a-standard-8 (32 GiB — headroom over the ~7.76 GiB OOM wall),
#           ZONE=us-central1-a, image=ubuntu-2404-lts-arm64, 60 GiB pd-balanced disk.
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}"
DEF_MACHINE="t2a-standard-8"
DEF_ZONE="us-central1-a"
IMG_FAMILY="ubuntu-2404-lts-arm64"
IMG_PROJECT="ubuntu-os-cloud"
DISK_GB=60

verb="${1:-}"; shift || true

case "$verb" in
  up)
    NAME="${1:-selfhost-arm64}"
    MACHINE="${2:-$DEF_MACHINE}"
    ZONE="${3:-$DEF_ZONE}"
    echo "[rent] creating $NAME ($MACHINE / $ZONE / $IMG_FAMILY / ${DISK_GB}GiB) in $PROJECT"
    gcloud compute instances create "$NAME" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --machine-type="$MACHINE" \
      --image-family="$IMG_FAMILY" \
      --image-project="$IMG_PROJECT" \
      --boot-disk-size="${DISK_GB}GB" \
      --boot-disk-type=pd-balanced \
      --no-restart-on-failure \
      --labels=lane=selfhost-next-arm64,ephemeral=true
    echo "[rent] created. waiting for SSH ..."
    for i in $(seq 1 40); do
      if gcloud compute ssh "$NAME" --zone="$ZONE" --project="$PROJECT" \
           --command="echo ssh-ok; uname -m; nproc; free -g | awk '/Mem:/{print \$2\" GiB\"}'" \
           -- -o ConnectTimeout=10 -o StrictHostKeyChecking=no 2>/dev/null; then
        echo "[rent] SSH up after ~$((i*10))s"
        exit 0
      fi
      sleep 10
    done
    echo "[rent] SSH never came up" >&2; exit 1
    ;;
  ssh)
    NAME="${1:?need NAME}"; shift
    ZONE="$DEF_ZONE"
    if [ "${1:-}" != "--" ]; then ZONE="$1"; shift; fi
    [ "${1:-}" = "--" ] && shift
    gcloud compute ssh "$NAME" --zone="$ZONE" --project="$PROJECT" \
      --command="$*" -- -o StrictHostKeyChecking=no
    ;;
  push)
    NAME="${1:?need NAME}"; SRC="${2:?need SRC}"; DEST="${3:?need DEST}"; ZONE="${4:-$DEF_ZONE}"
    gcloud compute scp --recurse "$SRC" "$NAME:$DEST" --zone="$ZONE" --project="$PROJECT" \
      -- -o StrictHostKeyChecking=no
    ;;
  pull)
    NAME="${1:?need NAME}"; SRC="${2:?need SRC}"; DEST="${3:?need DEST}"; ZONE="${4:-$DEF_ZONE}"
    gcloud compute scp --recurse "$NAME:$SRC" "$DEST" --zone="$ZONE" --project="$PROJECT" \
      -- -o StrictHostKeyChecking=no
    ;;
  down)
    NAME="${1:?need NAME}"; ZONE="${2:-$DEF_ZONE}"
    echo "[rent] DELETING $NAME ($ZONE) — teardown"
    gcloud compute instances delete "$NAME" --zone="$ZONE" --project="$PROJECT" --quiet
    echo "[rent] deleted."
    ;;
  *)
    echo "usage: $0 {up|ssh|push|pull|down} ..." >&2; exit 2 ;;
esac
