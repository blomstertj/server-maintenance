#!/bin/bash

pwsh docker-backup-container-volumes.ps1
systemctl stop docker
sudo journalctl --vacuum-time=1d
zypper refresh
zypper dup
zypper clean
fwupdmgr update --no-reboot-check
shutdown -r +1