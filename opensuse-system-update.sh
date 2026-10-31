#!/bin/bash

docker stop $(docker ps -q)
systemctl stop docker
zypper dup
zypper update
zypper clean
fwupdmgr update --no-reboot-check
shutdown -r +1
