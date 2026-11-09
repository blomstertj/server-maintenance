##############################################################################
#### README
## Author
# github.com/blomstertj
#
## Description
# PowerShell script to restore Docker volumes for all containers on a Linux host.
#
## Version
# 2026.11.08
#
##############################################################################


#region: User Configuration
# root path for all backups
$dockerBackupPathRoot = '/mnt/pool/samba-shares/shared/backups/docker'
# image to use for restoring volumes
$restoreDockerImage = 'alpine:edge'
# prune the restore image after the restore process is complete
$restoreDockerImageAutoPrune = $true
# get all container backup paths
$containerBackupPaths = Get-ChildItem -Path $dockerBackupPathRoot -Directory
#endregion

#region: Pull Restore Image
# pull the restore image to use for restoring volumes
docker pull $restoreDockerImage
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
        # log the creation of the restore container for restoring the volume
        #endregion

        #region: Create Restore Container for Restoring Volume
        Write-Output ('Creating restore container for restoring volume {0}' -f $volume.Name)
        # define the command to restore the volume within the restore container
        $restoreContainerRestoreTarCmdOpts = 'xzf'
        $restoreContainerRestoreTarCmd = 'tar -{0} /backup/{1} -C /target' -f $restoreContainerRestoreTarCmdOpts, ($volume.BackupPath | Split-Path -Leaf)
        $restoreContainerClearTargetCmd = 'rm -rf /target/*'
        $restoreCommand = '{0} && {1}' -f $restoreContainerClearTargetCmd, $restoreContainerRestoreTarCmd
        # run the restore container to restore the volume
        docker run --rm -v ('{0}:/target' -f $volume.Name) -v ('{0}:/backup:z,ro' -f $volumeBackupRootPath) $restoreDockerImage sh -c "$restoreCommand"
        #endregion
    }
    #endregion
}
#endregion

#region: Prune Docker Image Post Restore
if ($restoreDockerImageAutoPrune) {
    Write-Output '================================================='
    Write-Output ('Pruning Docker restore image {0} post restore' -f $restoreDockerImage)
    docker rmi $restoreDockerImage
}
#endregion
