#!/bin/bash
set -e

# This worker image's built-in extra_model_paths.yaml only maps the network
# volume's models/unet and models/clip folders (not the newer
# diffusion_models/text_encoders naming) — see /comfyui/extra_model_paths.yaml
# in the base image. These symlinks bridge that gap without touching the
# original start.sh, so ComfyUI's default folder scan finds the real files.
if [ -d /runpod-volume/models ]; then
  mkdir -p /comfyui/models
  ln -sfn /runpod-volume/models/text_encoders /comfyui/models/clip
  ln -sfn /runpod-volume/models/diffusion_models /comfyui/models/unet
  ln -sfn /runpod-volume/models/vae /comfyui/models/vae
fi

# Hand off to the original entrypoint unchanged — GPU checks, ComfyUI launch,
# and the RunPod job handler all still run exactly as the base image intends.
exec /start.sh
