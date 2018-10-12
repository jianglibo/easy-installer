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

function Get-MysqlVariables {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration,
        [parameter(Mandatory = $false, Position = 1)][string[]]$VariableNames
    )
    $sql = "{0} -uroot -p{1} -X -e `"{2}`"" -f $configuration.clientBin, $configuration.MysqlPassword, "show variables"
    $r = Invoke-Expression -Command $sql | Where-Object {-not ($_ -like 'Warning:*')}
    if ($VariableNames.Count -gt 0) {
        ([xml]$r).resultset.row | ForEach-Object {@{name=$_.field[0].'#text';value=$_.field[1].'#text'}} | Where-Object {$_.name -in $VariableNames} | ConvertTo-Json
    } else {
        ([xml]$r).resultset.row | ForEach-Object {@{name=$_.field[0].'#text';value=$_.field[1].'#text'}} | ConvertTo-Json
    }
}


function Uninstall-Mysql {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration
    )

    # datadir
}