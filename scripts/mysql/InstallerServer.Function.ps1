function Enable-RepoVersion {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$RepoFile,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet("55", "56", "57", "80")]
        [string]$Version
    )

    Get-Content $RepoFile | ForEach-Object -Begin {
        $currentVersion = ""
    } -Process {
        $notChanged = $true
        if (($_ -match '^\[.*?(\d+)-.*\]$')) {
            $currentVersion = $Matches[1]
        }
        elseif (($_ -match '^\[.*\]$')) {
            $currentVersion = "others"
        }
        else {
            if (($_ -match '^enabled=(0|1)$')) {
                if (($currentVersion -eq $Version)) {
                    "enabled=1"
                    $notChanged = $false
                }
                else {
                    # don't change value of other section.
                    if ($currentVersion -ne "others") {
                        "enabled=0"
                        $notChanged = $false
                    }
                }
            }
        }
        if ($notChanged) {
            $_
        }
    }
}

function Install-Mysql {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration,
        [parameter(Mandatory = $false)]
        [string]$Version
    )
    if (Test-SoftwareInstalled -configuration $configuration) {
        "AlreadyInstalled"
        return
    }
}

function Get-MycnfFile {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $r = Invoke-Expression -Command "$($configuration.clientBin) --help"
    $r = $r | ForEach-Object -Begin {
        $found = $false
    } -Process {
        if ($_ -match "Default options are read from the following files in the given order:") {
            $found = $true
        }
        else {
            if ($found) {
                $_
            }
            else {
                $found = $false
            }
        }
    } | Select-Object -First 1
    ([string]$r).Trim() -split '\s+' | Where-Object {Test-Path -Path $_} | Select-Object -First 1
}

function Uninstall-Mysql {

}