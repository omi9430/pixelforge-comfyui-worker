FROM registry.runpod.net/runpod-workers-worker-comfyui-main-dockerfile:066a11c49
COPY link-volume.sh /link-volume.sh
RUN chmod +x /link-volume.sh
ENTRYPOINT ["/link-volume.sh"]
