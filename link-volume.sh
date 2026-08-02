#!/bin/bash
set -e

# Log to local disk (guaranteed to exist immediately) as the primary record.
# A previous attempt logged only to the network volume and produced no file
# at all — the volume likely isn't fully mounted the instant this script
# starts, so that write raced the mount and silently failed.
exec > >(tee -a /comfyui/link-volume-debug.log) 2>&1
echo "=== [link-volume] run at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# Mirror the log to the network volume on ANY exit (success, hard-fail, or
# an unexpected crash) — not just at the end of a fully successful run —
# so a failure is still inspectable from a separate pod.
mirror_log() { cp -f /comfyui/link-volume-debug.log /runpod-volume/link-volume-debug.log 2>/dev/null || true; }
trap mirror_log EXIT

# This worker image's built-in extra_model_paths.yaml only maps the network
# volume's models/unet and models/clip folders (not the newer
# diffusion_models/text_encoders naming) — see /comfyui/extra_model_paths.yaml
# in the base image.
#
# Symlinking straight to the network volume isn't enough either: mmap()
# against RunPod's NFS-backed network volume is unreliable for large
# safetensors files (upstream ComfyUI issue #2288 — no built-in flag to
# disable mmap), which surfaces as "ModelMMAP allocation failed". So these
# are real copies onto local (mmap-safe) container disk, not symlinks.
# Needs enough Container Disk space for base image + all copied models.

# Waits (up to ~30s) for the network volume to actually be mounted, rather
# than assuming it's ready the instant this script starts.
for i in $(seq 1 30); do
  if [ -d /runpod-volume/models ]; then
    break
  fi
  echo "[link-volume] waiting for /runpod-volume/models to mount (attempt $i)..."
  sleep 1
done

if [ ! -d /runpod-volume/models ]; then
  echo "[link-volume] FATAL: /runpod-volume/models never appeared — network volume not attached?"
  exit 42
fi

echo "[link-volume] network volume found, copying models to local disk..."
mkdir -p /comfyui/models/clip/text_encoders /comfyui/models/unet /comfyui/models/vae

# Copies with an explicit size check against the source — a flaky NFS-backed
# network volume read can silently truncate a large file without cp itself
# reporting an error. Retries a few times, then hard-fails (visible as an
# "unhealthy" worker) rather than silently handing ComfyUI a broken file.
copy_verified() {
  local src="$1" dst_dir="$2" name expected actual attempt
  name="$(basename "$src")"
  expected=$(stat -c '%s' "$src")
  for attempt in 1 2 3; do
    echo "[link-volume] copying $name (attempt $attempt, expected ${expected} bytes)..."
    cp -f "$src" "$dst_dir/$name"
    actual=$(stat -c '%s' "$dst_dir/$name")
    if [ "$actual" = "$expected" ]; then
      echo "[link-volume] $name OK: $actual bytes"
      return 0
    fi
    echo "[link-volume] $name size mismatch: got $actual, expected $expected — retrying"
  done
  echo "[link-volume] FATAL: $name never copied correctly after 3 attempts"
  exit 43
}

for f in /runpod-volume/models/text_encoders/*.safetensors; do
  copy_verified "$f" /comfyui/models/clip/text_encoders
done
for f in /runpod-volume/models/diffusion_models/*.safetensors; do
  copy_verified "$f" /comfyui/models/unet
done
for f in /runpod-volume/models/vae/*.safetensors; do
  copy_verified "$f" /comfyui/models/vae
done

echo "[link-volume] all copies verified."

# Best-effort mirror of the log onto the network volume too, for inspection
# from a separate pod — failure here must not affect startup.
cp -f /comfyui/link-volume-debug.log /runpod-volume/link-volume-debug.log 2>/dev/null || true

# Hand off to the original entrypoint (renamed in the Dockerfile) unchanged
# — GPU checks, ComfyUI launch, and the RunPod job handler all still run
# exactly as the base image intends.
exec /start-original.sh
