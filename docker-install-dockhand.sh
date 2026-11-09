#!/bin/bash

# disable SELinux labeling
# reserve 256 MB of memory
# enable SELinux labeling for mounted socket

docker run -d \
  --security-opt label=disable \
  --name dockhand \
  --restart always \
  --memory-reservation=256M \
  -p 3000:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock:z \
  -v dockhand_data:/app/data \
  fnsys/dockhand:latest