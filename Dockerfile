FROM runpod/worker-comfyui:5.8.6-base

# AIMDO (ComfyUI's dynamic VRAM offloader) fails allocating an mmap for our
# text encoder with "ModelMMAP allocation failed" — disable it and fall
# back to ComfyUI's standard loader. start.sh has no args passthrough env
# var, so patch the launch line directly.
RUN sed -i 's/--disable-metadata/--disable-metadata --disable-dynamic-vram/' /start.sh

# RunPod's serverless launcher invokes /start.sh directly regardless of the
# image's own ENTRYPOINT/CMD (a custom ENTRYPOINT here was silently never
# run) — so instead of adding a new entrypoint, replace /start.sh itself
# and keep the original under a different name to hand off to at the end.
RUN mv /start.sh /start-original.sh
COPY link-volume.sh /start.sh
RUN chmod +x /start.sh
