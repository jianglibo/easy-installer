class MysqlVariableNames {
    static [string]$DATA_DIR = "datadir"
}
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

function Test-MysqlIsRunning {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration
    )
    try {
        Invoke-MysqlSQLCommand -configuration $configuration -sql "select 1" -combineError | Out-Null
        $true
    }
    catch {
        $false
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
    } else {
        $cmd = "yum install -y "
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

function Get-SQLCommandLine {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration,
        [parameter(Mandatory = $true, Position = 1)]$sql,
        [parameter()][switch]$combineError
    )
    "{0} -uroot -p{1} -X -e `"{2}`"{3}" -f $configuration.clientBin, $configuration.MysqlPassword, $sql, $(if ($combineError) {" 2>&1"} else {""})
}

function Invoke-MysqlSQLCommand {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration,
        [parameter(Mandatory = $true, Position = 1)]$sql,
        [parameter()][switch]$combineError
    )

    $sql = Get-SQLCommandLine -configuration $configuration -sql $sql -combineError:$combineError
    $r = Invoke-Expression -Command $sql | Where-Object {-not ($_ -like 'Warning:*')}
    $r | Write-Verbose
    if ($r -like "*Access Denied*") {
        throw "Mysql Access Denied."
    }
    elseif ($r -like "*Can't connect to*") {
        throw "Mysql is not started."
    }
    $r
}

<#
    
#>
function Get-MysqlVariables {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration,
        [parameter(Mandatory = $false, Position = 1)][string[]]$VariableNames
    )
    $r = Invoke-MysqlSQLCommand -configuration $configuration -sql "show variables" -combineError
    if ($VariableNames.Count -gt 0) {
        ([xml]$r).resultset.row | ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} | Where-Object {$_.name -in $VariableNames} | ConvertTo-Json -Depth 10
    }
    else {
        ([xml]$r).resultset.row | ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} | ConvertTo-Json -Depth 10
    }
}

function Uninstall-Mysql {
    param (
        [parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $osDetail = Get-OsDetail
    if ($osDetail.isUnix()) {
        try {
            $vh = Get-MysqlVariables -configuration $configuration -VariableNames [MysqlVariableNames]::DATA_DIR
            $r = systemctl stop mysqld
            Start-Sleep -Seconds 3
            if (Test-MysqlIsRunning -configuration $configuration) {
                "Fail to stop mysqld."
            } else {
                $r = "$(yum list installed | grep mysql | ForEach-Object {($_ -split "\s+",3)[0]} | Where-Object {$_ -like 'mysql-community*'})"
                $r = Invoke-Expression "yum remove -y $r"
                $nx = Backup-LocalDirectory -Path $vh.value
                if ($r -like "*Complete!*") {
                    "Uninstall successly."
                } else {
                    $r
                }
            }
        }
        catch {
            $Error[0].TargetObject
        }
    }
}