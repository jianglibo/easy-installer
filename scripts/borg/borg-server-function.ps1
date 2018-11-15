function Install-Borg {
    param (
        [parameter(Mandatory = $false)][string]$Version
    )
    if (Test-Path -Path $Global:configuration.BorgBin -PathType Leaf) {
        "AlreadyInstalled"
        return
    }
    else {
        $OsConfig = $Global:configuration.OsConfig
        Get-SoftwarePackages -TargetDir $OsConfig.ServerSide.PackageDir -Softwares $OsConfig.Softwares
        $pk = Get-SoftwarePackagePath
        Copy-Item -Path $pk -Destination $Global:configuration.BorgBin
        $chmod = "chmod 755 {0}" -f $Global:configuration.BorgBin
        "Install Succcess." | Send-LinesToClient
    }
}