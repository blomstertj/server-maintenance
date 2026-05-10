#!/bin/bash

docker stop $(docker ps -q)
systemctl stop docker
zypper dist-upgrade
snap refresh
shutdown -r +1
