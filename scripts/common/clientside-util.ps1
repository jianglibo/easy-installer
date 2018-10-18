$CommonScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "${CommonScriptsDir}\common-util.ps1"
function Copy-DemoConfigFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$MyDir,
        [Parameter(Mandatory = $true, Position = 1)][string]$ToFileName
    )
    $demofolder = $PWD | Join-Path -ChildPath "myconfigs"
    "MyDir is: $MyDir" | Write-Verbose
    "Checking existance of $demofolder ...." | Write-Verbose
    if (-not (Test-Path -Path $demofolder)) {
        New-Item -Path $demofolder -ItemType "directory"
    }
    $tofile = $demofolder | Join-Path -ChildPath $ToFileName
    "destination file is: $tofile" | Write-Verbose
    $srcfile = Join-Path -Path $MyDir -ChildPath "demo-config.json"
    "source file is: $srcfile" | Write-Verbose

    Copy-Item -Path $srcfile -Destination $tofile
    "The demo config file created at ${tofile}`n"
}
function Get-PublicKeyFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )
    if ($configuration.PublicKeyFile -like "default*") {
        $pk = $CommonScriptsDir | Split-Path -Parent | Split-Path -Parent |
            Join-Path -ChildPath "myconfigs" |
            Join-Path -ChildPath $configuration.HostName |
            Join-Path -ChildPath "public_key.pem"
        $pkrsolved = Resolve-Path -Path $pk -ErrorAction SilentlyContinue
    }
    else {
        $pkrsolved = Resolve-Path -Path $configuration.PublicKeyFile -ErrorAction SilentlyContinue
    }
    if (-not $pkrsolved) {
        Write-ParameterWarning -wstring "${pk} does'nt exists. If you don't want to encrypt the config file leave either of PrivateKeyFile or PublicKeyFile empty."
    }
    $pkrsolved
}

function Get-SoftwarePackages {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $dl = Join-Path -Path $PWD -ChildPath "downloads"
    if (-not (Test-Path -Path $dl -PathType Container)) {
        New-Item -Path $dl -ItemType "directory"
    }
    $configuration.Softwares | ForEach-Object {
        $url = $_.PackageUrl
        $ln = $_.LocalName
        if (-not $ln) {
            $ln = Split-Url -Url $url
        }
        $lf = Join-Path -Path $dl -ChildPath $ln
        if (-not (Test-Path -Path $lf -PathType Leaf)) {
            Invoke-WebRequest -Uri $url -OutFile $lf
        }
    }
}


# PS C:\>$Secure = Read-Host -AsSecureString
# PS C:\>$Encrypted = ConvertFrom-SecureString -SecureString $Secure -Key (1..16)
# PS C:\>$Encrypted | Set-Content Encrypted.txt
# PS C:\>$Secure2 = Get-Content Encrypted.txt | ConvertTo-SecureString -Key (1..16)
# $SecurePassword = Get-Content C:\Users\tmarsh\Documents\securePassword.txt | ConvertTo-SecureString
# $UnsecurePassword = (New-Object PSCredential "user",$SecurePassword).GetNetworkCredential().Password


function  Get-SshInvoker {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $sshInvoker = [SshInvoker]::new($configuration.HostName, $configuration.IdentityFile)
    $sshInvoker
}


function Copy-PsScriptToServer {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration,
        [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile,
        [Parameter(Mandatory = $true, Position = 2)][string]$ServerSideFileListFile
    )

    $files = Get-Content -Path $ServerSideFileListFile |
        ForEach-Object {Join-Path -Path $ServerSideFileListFile -ChildPath $_} |
        ForEach-Object {Resolve-Path -Path $_} |
        Select-Object -ExpandProperty Path
    # $files += $ConfigFile

    $filesToCopy = $files -join ' '
    $filesToCopy | Write-Verbose

    $sshInvoker = Get-SshInvoker -configuration $configuration
    $osConfig = Get-OsConfiguration -configuration $configuration

    $dst = $osConfig.ServerSide.ScriptDir
    if (-not $dst) {
        Write-ParameterWarning -wstring "There must have a value for ServerSide.ScriptDir in configuration file: $ConfigFile"
        return
    }
    $r = $sshInvoker.scp($filesToCopy, $dst, $true)

    if ($configuration.PrivateKeyFile -and $configuration.PublicKeyFile) {
        $ConfigFile = Protect-ByOpenSSL -PublicKeyFile (Get-PublicKeyFile -configuration $configuration) -PlainFile $ConfigFile
    }

    #copy configfile to fixed server name.
    $cfgServer = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'
    $rc = $sshInvoker.scp($ConfigFile, $cfgServer, $false)
    $sshInvoker | Out-String | Write-Verbose
    $r += $rc
}

<#
it's better to fix the configfile name on server side.
#>
function Invoke-ServerRunningPs1 {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration,
        [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$action,
        [parameter(Mandatory = $false)][switch]$notCombineError,
        [parameter(Mandatory = $false,
            ValueFromRemainingArguments = $true)]
        [String[]]
        $hints
    )
    $sshInvoker = Get-SshInvoker -configuration $configuration

    $osConfig = Get-OsConfiguration -configuration $configuration

    $toServerConfigFile = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'

    $entryPoint = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath $osConfig.ServerSide.EntryPoint
    
    $rcmd = "pwsh -f {0} -action {1} -ConfigFile {2} -privateKeyFile {3} {4}" -f $entryPoint, $action, $toServerConfigFile, (Get-Verbose), ($hints -join ' ')
    $rcmd | Out-String | Write-Verbose
    $sshInvoker.Invoke($rcmd, (-not $notCombineError))
}