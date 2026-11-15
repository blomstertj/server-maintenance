#!/bin/bash

journalctl --vacuum-time=1d
pwsh docker-backup-container-volumes.ps1
systemctl stop docker
systemctl stop containerd
zypper refresh
zypper dup
zypper clean
fwupdmgr update --no-reboot-check
shutdown -r +1