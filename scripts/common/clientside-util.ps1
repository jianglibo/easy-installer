$CommonScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $CommonScriptsDir | Split-Path -Parent | Split-Path  -Parent
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
    $c = $Global:configuration

    if ($c.PublicKeyFile -like "default*") {
        $pk = $CommonScriptsDir | Split-Path -Parent | Split-Path -Parent |
            Join-Path -ChildPath "myconfigs" |
            Join-Path -ChildPath $c.HostName |
            Join-Path -ChildPath "public_key.pem"
        $pkrsolved = Resolve-Path -Path $pk -ErrorAction SilentlyContinue
    }
    else {
        $pkrsolved = Resolve-Path -Path $c.PublicKeyFile -ErrorAction SilentlyContinue
    }
    if (-not $pkrsolved) {
        Write-ParameterWarning -wstring "${pk} does'nt exists. If you don't want to encrypt the config file leave either of PrivateKeyFile or PublicKeyFile empty."
    }
    $pkrsolved
}


function Send-SoftwarePackages {
    $c = $Global:configuration
    $dl = $ProjectRoot | Join-Path -ChildPath "downloads" | Join-Path -ChildPath $c.myname
    if (-not (Test-Path -Path $dl -PathType Container)) {
        New-Item -Path $dl -ItemType "directory"
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
        $r = $sshInvoker.scp($localFileNames, $dst, $true) 
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
        [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile,
        [Parameter(Mandatory = $true, Position = 2)][string]$ServerSideFileListFile
    )

    try {
        
        $td = New-TemporaryDirectory
        $tf = $td | Join-Path -ChildPath "config.json"

        Copy-Item -Path $ConfigFile -Destination $tf

        "Configuration File is: $ConfigFile" | Write-Verbose
        "temporary file is: $tf" | Write-Verbose

        $c = $Global:configuration
        $files = Get-Content -Path $ServerSideFileListFile |
            ForEach-Object {Join-Path -Path $ServerSideFileListFile -ChildPath $_} |
            ForEach-Object {Resolve-Path -Path $_} |
            Select-Object -ExpandProperty Path

        $tf = Resolve-Path -Path $tf | Select-Object -ExpandProperty ProviderPath

        $files +=  $tf

        $filesToCopy = $files -join ' '
        "files to copy: $filesToCopy" | Write-Verbose

        $sshInvoker = Get-SshInvoker
        $osConfig = $c.OsConfig

        $dst = $osConfig.ServerSide.ScriptDir
        if (-not $dst) {
            Write-ParameterWarning -wstring "There must have a value for ServerSide.ScriptDir in configuration file: $ConfigFile"
            return
        }
        $r = $sshInvoker.scp($filesToCopy, $dst, $true)

        "files copied: $r" | Write-Verbose

        $r
    }
    finally {
        Remove-Item -Path $td -Recurse -Force
    }

    # unnecessary to encrypt whole configuration file. Because We had encrypt the password in it.

    # if ($c.PrivateKeyFile -and $c.PublicKeyFile) {
    #     $ConfigFile = Protect-ByOpenSSL -PublicKeyFile (Get-PublicKeyFile) -PlainFile $ConfigFile
    # }

    # #copy configfile to fixed server name.
    # $cfgServer = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'
    # $rc = $sshInvoker.scp($ConfigFile, $cfgServer, $false)
    # $sshInvoker | Out-String | Write-Verbose
    # $r += $rc
}

<#
it's better to fix the configfile name on server side.
#>
function Invoke-ServerRunningPs1 {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Action,
        [parameter(Mandatory = $false)][switch]$notCombineError,
        [parameter(Mandatory = $false,
            ValueFromRemainingArguments = $true)]
        [String[]]
        $hints
    )
    $c = $Global:configuration
    $sshInvoker = Get-SshInvoker

    $osConfig = $c.OsConfig

    # it's a fixed name on server. so it's no necessary to tell the server script where it is.
    # $toServerConfigFile = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath 'config.json'

    $entryPoint = Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath $osConfig.ServerSide.EntryPoint
    
    $rcmd = "pwsh -f {0} -action {1} {2} {3}" -f $entryPoint, $action, (Get-Verbose), ($hints -join ' ')
    $rcmd | Out-String | Write-Verbose
    $sshInvoker.Invoke($rcmd, (-not $notCombineError))
}