#!/bin/bash

pwsh docker-backup-container-volumes.ps1
systemctl stop docker
zypper dup
#zypper update
zypper clean
fwupdmgr update --no-reboot-check
shutdown -r +1