#!/bin/bash
set -e

# TEMPORARY DIAGNOSTIC CANARY: if this image is actually what RunPod runs,
# the worker must fail to start. If it instead starts fine and reaches
# "got prompt", the image/entrypoint below is being bypassed entirely
# (e.g. FlashBoot resuming an old snapshot) rather than our fix not working.
echo "[link-volume] CANARY: if you see this, the entrypoint DID run. Exiting on purpose."
exit 17

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
echo "[link-volume] image build marker: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -d /runpod-volume/models ]; then
  echo "[link-volume] network volume found, copying models to local disk..."
  mkdir -p /comfyui/models/clip/text_encoders /comfyui/models/unet /comfyui/models/vae

  # Nested "clip/text_encoders/" because ComfyUI resolves clip_name there
  # once the clip/text_encoders folder categories are merged internally.
  # -f (not -n): a warm/reused worker container can already have a stale,
  # empty, or partial file from an earlier attempt at this same path, and
  # -n would skip over it, leaving the broken file in place forever.
  cp -v -f /runpod-volume/models/text_encoders/*.safetensors /comfyui/models/clip/text_encoders/
  cp -v -f /runpod-volume/models/diffusion_models/*.safetensors /comfyui/models/unet/
  cp -v -f /runpod-volume/models/vae/*.safetensors /comfyui/models/vae/

  echo "[link-volume] copy done, verifying (size in bytes):"
  find /comfyui/models/clip/text_encoders /comfyui/models/unet /comfyui/models/vae -name '*.safetensors' -exec stat -c '%n %s' {} \;
else
  echo "[link-volume] WARNING: /runpod-volume/models not found — network volume not attached?"
fi

# Hand off to the original entrypoint (renamed in the Dockerfile) unchanged
# — GPU checks, ComfyUI launch, and the RunPod job handler all still run
# exactly as the base image intends.
exec /start-original.sh
