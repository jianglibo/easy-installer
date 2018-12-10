if ($Global:CommonUtil) {
    . $Global:CommonUtil
}

if ($Global:SshInvoker) {
    . $Global:SshInvoker
}
function Get-AppName {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$MyDir
    )
    (Get-Content -Path (Join-Path -Path $MyDir -ChildPath "demo-config.json") | ConvertFrom-Json).AppName
}

function Copy-DemoConfigFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$MyDir,
        [Parameter(Mandatory = $true, Position = 1)][string]$HostName,
        [Parameter(Mandatory = $true, Position = 2)][string]$ToFileName
    )
    $demofolder = $PWD | Join-Path -ChildPath "myconfigs" | Join-Path -ChildPath $HostName
    "MyDir is: $MyDir" | Write-Verbose
    "Checking existance of $demofolder ...." | Write-Verbose
    if (-not (Test-Path -Path $demofolder)) {
        New-Item -Path $demofolder -ItemType "directory" | Out-Null
    }
    $tofile = $demofolder | Join-Path -ChildPath $ToFileName
    "destination file is: $tofile" | Write-Verbose
    $srcfile = Join-Path -Path $MyDir -ChildPath "demo-config.json"
    "source file is: $srcfile" | Write-Verbose

    $h = Get-Content -Path $srcfile | ConvertFrom-Json
    $h.HostName = $HostName
    # Copy-Item -Path $srcfile -Destination $tofile
    $h | ConvertTo-Json -Depth 10 | Out-File $tofile
    "The demo config file created at ${tofile}`n"
}
function Get-PublicKeyFile {
    param (
        [switch]$NotResolve
    )
    $c = $Global:configuration

    if ($c.PublicKeyFile -like "default*") {
        $pk = $Global:CommonDir | Split-Path -Parent | Split-Path -Parent |
            Join-Path -ChildPath "myconfigs" |
            Join-Path -ChildPath $c.HostName |
            Join-Path -ChildPath "public_key.pem"
    }
    else {
        $pk = $c.PublicKeyFile
    }
    $pkrsolved = Resolve-Path -Path $pk -ErrorAction SilentlyContinue
    if ($NotResolve) {
        $pk
    }
    else {
        if (-not $pkrsolved) {
            Write-ParameterWarning -wstring "${pk} does'nt exists. If you don't want to encrypt the config file leave either of PrivateKeyFile or PublicKeyFile empty."
        }
        $pkrsolved
    }
}

function Write-ActionResultToLogFile {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Value,
        [string]$Action,
        [switch]$LogResult
    )
    if ($LogResult) {
        $Value | ConvertTo-Json -Depth 10 | Out-File -FilePath (Get-LogFile -group $Action)
    }
}

function Out-JsonOrOrigin {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Value,
        [switch]$Json,
        [Parameter(Mandatory = $false)]
        [int16]$Depth = 10
    )
    if ($Json) {
        $Value | ConvertTo-Json -Depth $Depth
    }
    else {
        $Value
    }
}

function Send-SoftwarePackages {
    $c = $Global:configuration
    $dl = $ProjectRoot | Join-Path -ChildPath "downloads" | Join-Path -ChildPath $c.AppName
    if (-not (Test-Path -Path $dl -PathType Container)) {
        New-Item -Path $dl -ItemType "directory" | Out-Null
    }
    $osConfig = $c.OsConfig
    $localFileNames = $osConfig.Softwares | ForEach-Object {
        $url = $_.PackageUrl
        $ln = $_.LocalName
        if (-not $ln) {
            $ln = Split-Url -Url $url
        }
        Join-Path -Path $dl -ChildPath $ln
    }

    [array]$unexists = $localFileNames | Where-Object {-not (Test-Path -Path $_ -PathType Leaf)}
    if ($unexists.Count -gt 0) {
        Write-ParameterWarning -wstring "Following files doesn't download yet: $($unexists -join ',')"
    }
    else {
        $sshInvoker = Get-SshInvoker
        $dst = $osConfig.ServerSide.PackageDir
        if (-not $dst) {
            Write-ParameterWarning -wstring "There must have a value for ServerSide.PackageDir in configuration file: $ConfigFile"
            return
        }
        $r = $sshInvoker.ScpTo($localFileNames, $dst, $true) 
    }
}


# PS C:\>$Secure = Read-Host -AsSecureString
# PS C:\>$Encrypted = ConvertFrom-SecureString -SecureString $Secure -Key (1..16)
# PS C:\>$Encrypted | Set-Content Encrypted.txt
# PS C:\>$Secure2 = Get-Content Encrypted.txt | ConvertTo-SecureString -Key (1..16)
# $SecurePassword = Get-Content C:\Users\tmarsh\Documents\securePassword.txt | ConvertTo-SecureString
# $UnsecurePassword = (New-Object PSCredential "user",$SecurePassword).GetNetworkCredential().Password


function  Get-SshInvoker {
    $c = $Global:configuration
    $sshInvoker = [SshInvoker]::new($c.HostName, $c.IdentityFile)
    $sshInvoker
}


function Copy-PsScriptToServer {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile
    )
    try {
        $c = $Global:configuration
        $filesExcludeConfig = $c.ServerSideFileList |
            ForEach-Object {Join-Path -Path $Global:ScriptDir -ChildPath $_} |
            ForEach-Object {Resolve-Path -Path $_} |
            Select-Object -ExpandProperty Path
        
        $filehashfile = Join-Path -Path $Global:ProjectTmpDir -ChildPath 'copingfiles.json'

        if (Test-Path $filehashfile) {
            $mp = Get-Content -Path $filehashfile | ConvertFrom-Json
            $unmatch = (Get-FileHash -Path $ConfigFile).Hash -ne $mp."config.json"
            if (-not $unmatch) {
                $unmatch = $filesExcludeConfig | Where-Object {
                    $nowhash = (Get-FileHash -Path $_).Hash
                    $oldhash = $mp.$_
                    $nowhash -ne $oldhash
                } | Select-Object -First 1
            }
            if (-not $unmatch) {
                "no changed file" | Write-Verbose
                return
            }
        }

        $td = New-TemporaryDirectory
        $tf = $td | Join-Path -ChildPath "config.json"

        Copy-Item -Path $ConfigFile -Destination $tf

        "Configuration File is: $ConfigFile" | Write-Verbose
        "temporary file is: $tf" | Write-Verbose


        $tf = Resolve-Path -Path $tf | Select-Object -ExpandProperty ProviderPath

        $files = $filesExcludeConfig + $tf


        $filesToCopy = $files -join ' '
        "files to copy: $filesToCopy" | Write-Verbose

        $sshInvoker = Get-SshInvoker
        $osConfig = $c.OsConfig

        $dst = $osConfig.ServerSide.ScriptDir
        if (-not $dst) {
            Write-ParameterWarning -wstring "There must have a value for ServerSide.ScriptDir in configuration file: $ConfigFile"
            return
        }

        # $rmcmd = "pwsh -Command '& {remove-item -Path " + $dst + "/* -recurse -force}'"
        # $rmcmd | Write-Verbose
        # $sshInvoker.Invoke($rmcmd)

        $r = $sshInvoker.ScpTo($filesToCopy, $dst, $true)
        "files copied: $r" | Write-Verbose
        $fhs = @{}
        $filesExcludeConfig | ForEach-Object {
                $fhs[$_] = (Get-FileHash -Path $_).Hash
        }
        $fhs."config.json" = (Get-FileHash -Path $ConfigFile).Hash
        $fhs | ConvertTo-Json | Out-File $filehashfile
    }
    finally {
        if ($td) {
            Remove-Item -Path $td -Recurse -Force
        }
    }

    # unnecessary to encrypt whole configuration file. Because We had encrypt the password in it.
    # if ($c.PrivateKeyFile -and $c.PublicKeyFile) {
    #     $ConfigFile = Protect-ByOpenSSL -PublicKeyFile (Get-PublicKeyFile) -PlainFile $ConfigFile
    # }

    # #copy configfile to fixed server name.
    # $cfgServer = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'
    # $rc = $sshInvoker.ScpTo($ConfigFile, $cfgServer, $false)
    # $sshInvoker | Out-String | Write-Verbose
    # $r += $rc
}

<#
it's better to fix the configfile name on server side.
#>


function Get-MaxLocalDir {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][switch]$Next

    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }
    if (-not (Test-Path -Path $configuration.LocalDir -PathType Container)) {
        New-Item -Path $configuration.LocalDir -ItemType 'Directory' | Out-Null
    }
    $bd = $configuration.LocalDir | 
        Join-Path -ChildPath $configuration.HostName | 
        Join-Path -ChildPath "$($configuration.AppName)s" |
        Join-Path -ChildPath $configuration.AppName
    if ($Next) {
        $maxb = Get-NextBackup -Path $bd
    }
    else {
        $maxb = Get-MaxBackup -Path $bd
    }

    if (-not (Test-Path -Path $maxb -PathType Container)) {
        New-Item -Path $maxb -ItemType 'Directory' | Out-Null
    }
    $maxb
}

function Get-LogFile {
    param (
        [Parameter(Mandatory = $false)]$configuration,
        [Parameter(Mandatory = $false)][string]$group,
        [Parameter(Mandatory = $false)][string]$name
    )
    if (-not $configuration) {
        $configuration = $Global:configuration
    }

    if (-not $configuration.LogDir) {
        throw 'configuration file has no LogDir property.'
    }
    if (-not $group) {
        $group = 'logs'
    }
    if (-not $name) {
        $name = '{0:yyyyMMddHHmmss}.log' -f (Get-Date)
    }
    if (-not (Test-Path -Path $configuration.LogDir -PathType Container)) {
        New-Item -Path $configuration.LogDir -ItemType 'Directory' | Out-Null
    }
    $bd = $configuration.LogDir |
        Join-Path -ChildPath $configuration.HostName | 
        Join-Path -ChildPath $configuration.AppName |
        Join-Path -ChildPath $group

    if (-not (Test-Path -Path $bd -PathType Container)) {
        New-Item -Path $bd -ItemType 'Directory' | Out-Null
    }
    $bd | Join-Path -ChildPath $name
}
