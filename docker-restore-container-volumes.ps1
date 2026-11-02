##############################################################################
#### README
## Author
# github.com/blomstertj
#
## Description
# PowerShell script to restore Docker volumes for all containers on a Linux host.
#
## Version
# 2026.10.31
#
##############################################################################


#region: Backup Root Path Configuration
# root path for all backups
$dockerBackupPathRoot = '/mnt/pool/docker-backups/containers'
# get all container backup paths
$containerBackupPaths = Get-ChildItem -Path $dockerBackupPathRoot -Directory
#endregion

#region: Pull Alpine Image
# pull the edge Alpine image to use for backing up volumes
$dockerImage = 'alpine:edge'
docker pull $dockerImage
#endregion

#region: Restore Volumes for Each Container
# iterate over each container backup path and restore its volumes
foreach ($containerBackupPath in $containerBackupPaths) {
    #region: Container Volumes Restore Setup
    # log the start of restoring volumes for the current container
    Write-Output '================================================='
    Write-Output ('Restoring volumes for container {0} ' -f $containerBackupPath.Name)
    # define the root path for the volume backups within the container backup path
    $volumeBackupRootPath = Join-Path -Path $containerBackupPath.FullName -ChildPath 'volumes'
    # define the path to the JSON configuration file for the volume backups
    $volumeBackupConfigPath = Join-Path -Path $volumeBackupRootPath -ChildPath 'volumes.json'
    # read the JSON configuration file for the volume backups
    $volumeBackupConfig = Get-Content -Path $volumeBackupConfigPath | ConvertFrom-Json
    #endregion

    #region: Restore Volumes for the Current Container
    # iterate over each volume in the JSON configuration and restore it
    foreach ($volume in $volumeBackupConfig) {
        #region: Restore Volume Setup
        Write-Output '========================='
        # log the restoration of the current volume
        Write-Output ('Restoring volume {0} from backup {1}' -f $volume.Name, $volume.BackupPath)
        # create the Docker volume if it doesn't exist
        $dockerVolumeCreate = docker volume create $volume.Name
        Write-Output ('Created Docker volume {0}' -f $dockerVolumeCreate)
        # log the creation of the Alpine container for restoring the volume
        #endregion

        #region: Create Alpine Container for Restoring Volume
        Write-Output ('Creating Alpine container for restoring volume {0}' -f $volume.Name)
        # define the command to restore the volume within the Alpine container
        $alpineBackupRestoreCommand = 'rm -rf /target/* && tar -xzf /backup/{0} -C /target' -f ($volume.BackupPath | Split-Path -Leaf)
        # run the Alpine container to restore the volume
        docker run --rm -v ('{0}:/target' -f $volume.Name) -v ('{0}:/backup' -f $volumeBackupRootPath) $dockerImage sh -c "$alpineBackupRestoreCommand"
        #endregion
    }
    #endregion
}
#endregion
