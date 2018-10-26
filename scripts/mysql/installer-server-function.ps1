class MysqlVariableNames {
    static [string]$DATA_DIR = "datadir"
}

$Global:EmptyPassword="USE-EMPTY-PASSWORD"
function Enable-RepoVersion {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$RepoFile,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet("55", "56", "57", "80")]
        [string]$Version
    )
    Backup-LocalDirectory -Path $RepoFile -keepOrigin
    $content = Get-Content $RepoFile | ForEach-Object -Begin {
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

    $content | Out-File -FilePath $RepoFile -Encoding ascii
}

function Test-MysqlIsRunning {
    try {
        Invoke-MysqlSQLCommand -sql "select 1" -combineError | Out-Null
        $true
    }
    catch {
        $false
    }
}

function Update-MysqlStatus {
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet("Start", "Stop", "Restart", "Status")]
        [string]
        $StatusTo
    )

    $c = "${StatusTo}Command"
    $ServerSide = $Global:configuration.OsConfig.ServerSide
    $cmd = $ServerSide.$c + " 2>&1"
    $cmd | Write-Verbose
    Invoke-Expression -Command $cmd
}

function Update-MysqlPassword {
    param (
        [parameter(Mandatory = $true)][string]$EncryptedNewPassword,
        [parameter(Mandatory = $false)][string]$EncryptedOldPassword
    )
    $plainp = UnProtect-PasswordByOpenSSLPublicKey -base64 $EncryptedNewPassword
    if (-not $EncryptedOldPassword) {
        $sql = "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${plainp}');" # old
        $r = Invoke-MysqlSQLCommand -sql $sql -UsePassword $Global:EmptyPassword
        $r = $r | Where-Object {$PSItem -like "*mysql_upgrade*"} | Select-Object -First 1

        if ($r) {
            $sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '${plainp}';" #new > 5.7.6
            $r = Invoke-MysqlSQLCommand -sql $sql -UsePassword $Global:EmptyPassword
        }
    }
    else {

    }
}

function Install-Mysql {
    param (
        [parameter(Mandatory = $false)][string]$Version
    )
    if (Test-SoftwareInstalled -OneSoftware $Global:configuration.OsConfig.ServerSide.Software) {
        Invoke-MysqlSQLCommand -sql "select 1"
        "AlreadyInstalled"
        return
    }
    else {
        $OsConfig = $Global:configuration.OsConfig
        Get-SoftwarePackages -TargetDir $OsConfig.ServerSide.PackageDir -Softwares $OsConfig.Softwares
        Enable-RepoVersion -RepoFile "/etc/yum.repos.d/mysql-community.repo" -Version $Version
        $cmd = "yum install -y mysql-community-server"
        $cmd | Write-Verbose
        Invoke-Expression -Command $cmd
        Update-MysqlStatus -StatusTo Start
        Update-MysqlPassword -EncryptedNewPassword $Global:configuration.MysqlPassword
        "Install Succcess." | Send-LinesToClient
    }
}

function Get-MycnfFile {
    $r = Invoke-Expression -Command "$($Global:configuration.clientBin) --help"
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

function Test-EmptyMysqlPassword {
    $c = $Global:configuration
    $cmd = "{0} -X -e `"select 1`"" -f $c.clientBin
    Invoke-Expression -Command $cmd | Where-Object {$PSItem -like "*Access denied*"} | Select-Object -First 1
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER sql
Parameter description

.PARAMETER UsePassword
The value 'USE-EMPTY-PASSWORD' has special meaning.

.PARAMETER SQLFromFile
Parameter description

.PARAMETER combineError
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-SQLCommandLine {
    param (
        [parameter(Mandatory = $true, Position = 0)]$sql,
        [parameter(Mandatory = $false)][string]$UsePassword,
        [parameter()][switch]$SQLFromFile,
        [switch]$combineError
    )
    $c = $Global:configuration

    if ($UsePassword) {
        if ($UsePassword -eq $Global:EmptyPassword) {
            $pw = ""
        }
        else {
            $pw = $UsePassword
        }
        $t = New-TemporaryFile
        "[client]", "user=$($c.MysqlUser)", "password=$pw" | Out-File -FilePath $t -Encoding ascii
    }
    else {
        if (-not $Global:MysqlExtraFile) {
            $pw = UnProtect-PasswordByOpenSSLPublicKey -base64 $c.MysqlPassword
            $t = New-TemporaryFile
            "[client]", "user=$($c.MysqlUser)", "password=$pw" | Out-File -FilePath $t -Encoding ascii
            $t = $Global:MysqlExtraFile
        }
        else {
            $t = $Global:MysqlExtraFile
        }
    }
    
    #  mysql  --defaults-extra-file=extra.txt -X  -e "select 1"
    if ($SQLFromFile) {
        $sqltmp = New-TemporaryFile
        $sql | Out-File -FilePath $sqltmp -Encoding ascii
        $cmdline = "Get-Content -Path {0} | {1} --defaults-extra-file={2} -X {3}" -f $sqltmp.FullName, $c.clientBin, $t, $(if ($combineError) {" 2>&1"} else {""})
        @{cmdline = $cmdline; extrafile = $t; sqltmp = $sqltmp}
    }
    else {
        $cmdline = "{0} --defaults-extra-file={1} -X -e `"{2}`"{3}" -f $c.clientBin, $t, $sql, $(if ($combineError) {" 2>&1"} else {""})
        if ($UsePassword) {
            @{cmdline = $cmdline; extrafile = $t; nopass = $true}
        }
        else {
            @{cmdline = $cmdline; extrafile = $t}
        }
    }
}

<#
 .SYNOPSIS
 Short description
 
 .DESCRIPTION
 Long description
 
 .PARAMETER sql
 Parameter description
 
 .PARAMETER UsePassword
 The value 'USE-EMPTY-PASSWORD' has special meaning.
 
 .PARAMETER SQLFromFile
 Parameter description
 
 .PARAMETER combineError
 Parameter description
 
 .EXAMPLE
 An example
 
 .NOTES
 General notes
 #>
function Invoke-MysqlSQLCommand {
    param (
        [parameter(Mandatory = $true, Position = 0)]$sql,
        [parameter(Mandatory = $false)][string]$UsePassword,
        [parameter()][switch]$SQLFromFile,
        [parameter()][switch]$combineError
    )

    $cmdline = Get-SQLCommandLine -sql $sql -combineError:$combineError -UsePassword $UsePassword -SQLFromFile:$SQLFromFile
    $cmdline | Write-Verbose
    $r = Invoke-Expression -Command $cmdline.cmdline | Where-Object {-not ($_ -like 'Warning:*')}
    $r | Write-Verbose
    if ($cmdline.sqltmp -and (Test-Path -Path $cmdline.sqltmp)) {
        "deleting tmp sqlfile: $($cmdline.sqltmp)" | Write-Verbose
        Remove-Item -Path $cmdline.sqltmp -Force
    }
    if ($cmdline.nopass -and $cmdline.extrafile -and (Test-Path -Path $cmdline.extrafile)) {
        "deleting emptypass extrafile: $($cmdline.sqltmp)" | Write-Verbose
    }
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
        [parameter(Mandatory = $false, Position = 1)][string[]]$VariableNames
    )
    $r = Invoke-MysqlSQLCommand -sql "show variables" -combineError
    if ($VariableNames.Count -gt 0) {
        ([xml]$r).resultset.row | ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} | Where-Object {$_.name -in $VariableNames} | ConvertTo-Json -Depth 10
    }
    else {
        ([xml]$r).resultset.row | ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} | ConvertTo-Json -Depth 10
    }
}

function Uninstall-Mysql {
    $UninstallCommand = $Global:configuration.OsConfig.ServerSide.UninstallCommand
    $StopCommand = $Global:configuration.OsConfig.ServerSide.StopCommand
    $vh = Get-MysqlVariables -VariableNames [MysqlVariableNames]::DATA_DIR
    Invoke-Expression -Command $StopCommand
    $r = Invoke-Expression -Command $UninstallCommand
    Backup-LocalDirectory -Path $vh.value
    # $osDetail = Get-OsDetail
    # if ($osDetail.isUnix()) {
    #     try {
    #         $vh = Get-MysqlVariables -VariableNames [MysqlVariableNames]::DATA_DIR
    #         $r = systemctl stop mysqld
    #         Start-Sleep -Seconds 3
    #         if (Test-MysqlIsRunning) {
    #             "Fail to stop mysqld."
    #         } else {
    #             $r = "$(yum list installed | grep mysql | ForEach-Object {($_ -split "\s+",3)[0]} | Where-Object {$_ -like 'mysql-community*'})"
    #             $r = Invoke-Expression "yum remove -y $r"
    #             $nx = Backup-LocalDirectory -Path $vh.value
    #             if ($r -like "*Complete!*") {
    #                 "Uninstall successly."
    #             } else {
    #                 $r
    #             }
    #         }
    #     }
    #     catch {
    #         $Error[0].TargetObject
    #     }
    # }
}