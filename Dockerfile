FROM runpod/worker-comfyui:5.8.6-base
COPY link-volume.sh /link-volume.sh
RUN chmod +x /link-volume.sh
ENTRYPOINT ["/link-volume.sh"]
