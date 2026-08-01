FROM runpod/worker-comfyui:5.8.6-base
COPY link-volume.sh /link-volume.sh
RUN chmod +x /link-volume.sh && \
    # AIMDO (ComfyUI's dynamic VRAM offloader) fails allocating an mmap for
    # our text encoder with "ModelMMAP allocation failed" — disable it and
    # fall back to ComfyUI's standard loader. start.sh has no args
    # passthrough env var, so patch the launch line directly.
    sed -i 's/--disable-metadata/--disable-metadata --disable-dynamic-vram/' /start.sh
ENTRYPOINT ["/link-volume.sh"]
