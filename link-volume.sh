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

  # ComfyUI validated clip_name against the bare filename, but at load time
  # re-resolved it as ".../clip/text_encoders/<file>" — a "text_encoders/"
  # prefix that only exists when the clip/text_encoders folder categories
  # get merged internally. A self-referencing symlink one level down makes
  # both resolution styles land on the same real file.
  ln -sfn /runpod-volume/models/text_encoders /runpod-volume/models/text_encoders/text_encoders
fi

# Hand off to the original entrypoint unchanged — GPU checks, ComfyUI launch,
# and the RunPod job handler all still run exactly as the base image intends.
exec /start.sh
