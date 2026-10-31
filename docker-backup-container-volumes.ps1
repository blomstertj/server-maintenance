##############################################################################
#### README
## Author
# github.com/blomstertj
#
## Description
# PowerShell script to backup Docker volumes for all containers on a Linux host.
# Example directory tree post backup 
# $dockerBackupPathRoot
# ├── container1
# │   ├── container.json
# │   └── volumes
# │       ├── volumes.json (contains custom BackupPath for each volume)
# │       └── container1-volume1_backup_2024.06.06_12.00.tar
# |        └── container1-volume2_backup_2024.06.06_12.00.tar
# └── container2
#     ├── container.json
#     └── volumes
#         ├── volumes.json (contains custom BackupPath for each volume)
#         └── container2-volume1_backup_2024.06.06_12.00.tar
#         └── container2-volume2_backup_2024.06.06_12.00.tar
## Version
# 2026.10.31
#
# ##############################################################################


#region: Backup Root Path Configuration
# root path for all backups
$dockerBackupPathRoot = '/mnt/pool/docker-backups/containers'
#endregion

#region: Pull Alpine Image
# pull the edge Alpine image to use for backing up volumes
docker pull alpine:edge
#endregion

#region: Get All Container Names
# container names to backup
$containerNames = (docker container list --all --format 'json' | ConvertFrom-Json).Names
#endregion

#region: Backup All Container Volumes
foreach ($containerName in $containerNames) {
    #region: Container Backup Setup
    Write-Output '================================================='
    Write-Output ('Processing container {0}' -f $containerName)
    # stop the container before performing the backup
    docker stop $containerName
    # get container config
    $container = docker inspect --format 'json' $containerName | ConvertFrom-Json
    # remove the leading slash from the container name for use in the file path
    $containerName = $container.Name.Replace('/', '')
    # container backup root path
    $containerExportPathRoot = Join-Path -Path $dockerBackupPathRoot -ChildPath $containerName
    #endregion

    #region: Container Backup Directory Setup
    # create container backup root path if it doesn't exist
    if (-not (Test-Path -Path $containerExportPathRoot)) {
        New-Item -Path $containerExportPathRoot -ItemType Directory -Force | Out-Null
    }
    # define the root path for the volume backups within the container backup path
    $containerVolumeExportPathRoot = Join-Path -Path $containerExportPathRoot -ChildPath 'volumes'
    # create the volume backup root path if it doesn't exist
    if (-not (Test-Path -Path $containerVolumeExportPathRoot)) {
        New-Item -Path $containerVolumeExportPathRoot -ItemType Directory -Force | Out-Null
    }
    #endregion

    #region: Container Configuration Export
    # export the container configuration to a JSON file
    $containerConfigExportPath = Join-Path -Path $containerExportPathRoot -ChildPath 'container.json'
    $container | ConvertTo-Json -Compress -Depth 10 | Out-File -FilePath $containerConfigExportPath
    #endregion

    #region: Container Volumes Backup Setup
    # get attached container volumes
    $containerMounts = $container.Mounts | Where-Object 'Type' -eq 'volume'
    # initialize the volume backup configuration array
    $volumeBackupConfigs = @()
    # define the path for the volume configuration export file
    $volumeBackupConfigPath = Join-Path -Path $containerVolumeExportPathRoot -ChildPath 'volumes.json'
    #endregion

    #region: Container Volumes Backup Execution
    foreach ($volume in $containerMounts) {
        Write-Output '========================='
        Write-Output ('Processing volume {0}' -f $volume.Name)
        #region: Volume Backup Archive Setup
        # define the file name for the volume backup archive
        $volumeArchiveName = '{0}-volume_backup_{1}.tar' -f $volume.Name, (Get-Date -Format 'yyyy.MM.dd')
        # define the full path for the volume backup archive
        $volumeArchivePath = Join-Path -Path $containerVolumeExportPathRoot -ChildPath $volumeArchiveName
        # remove existing backup if it exists
        if (Test-Path -Path $volumeArchivePath) { Remove-Item -Path $volumeArchivePath }
        #endregion

        #region: Volume Backup Execution
        # log the backup operation
        Write-Output ('Backing up {0} volume {1} to {2}/{3}' -f $containerName, $volume.Name, $containerExportPathRoot, $volumeArchiveName)
        #region: Create Alpine Container for Backing Up Volume
        Write-Output ('Creating Alpine container for backing up volume {0}' -f $volume.Name)
        # define the command to backup the volume within the Alpine container
        # tar -czf /path/to/archive.tar -C /path/to/sourceFolder /archive/start/path (. means no leading path component in the archive)
        $alpineBackupBackupCommand = 'tar -czf /backup/{0} -C /target .' -f $volumeArchiveName
        # run the Alpine container to backup the volume
        docker run --rm -v ('{0}:/target' -f $volume.Name) -v ('{0}:/backup' -f $containerVolumeExportPathRoot) alpine:latest sh -c "$alpineBackupBackupCommand"
        #endregion

        #region: Volume Backup Configuration Update
        # add the volume archive path to the JSON configuration
        $volume | Add-Member -NotePropertyName 'BackupPath' -NotePropertyValue $volumeArchivePath
        # add the updated volume configuration to the volume backup configuration array
        $volumeBackupConfigs += $volume
        #endregion
    }
    #endregion

    #region: Container Volumes Backup Configuration Export
    # write the container volumes configuration to the JSON file
    $volumeBackupConfigs | ConvertTo-Json -Compress -Depth 10 | Out-File -FilePath $volumeBackupConfigPath
    #endregion

    docker start $containerName
}
#endregion
