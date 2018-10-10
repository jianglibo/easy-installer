$CommonScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "${CommonScriptsDir}\common-util.ps1"
function Copy-DemoConfigFile {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$MyDir,
        [Parameter(Mandatory = $true, Position = 1)][string]$ToFileName
    )
    $demofolder = $PWD | Join-Path -ChildPath "demo-configs"
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
    $files += $ConfigFile

    $filesToCopy = $files -join ' '
    $filesToCopy | Write-Verbose

    $sshInvoker = Get-SshInvoker -configuration $configuration
    $dst = $configuration.ServerSide.ScriptDir
    if (-not $dst) {
        Write-ParameterWarning -wstring "There must have a value for ServerSide.ScriptDir in configuration file: $ConfigFile"
        return
    }
    $r = $sshInvoker.scp($filesToCopy, $configuration.ServerSide.ScriptDir, $true)
    $sshInvoker | Out-String | Write-Verbose
    "copied files:"
    $r -split ' '
}

function Invoke-ServerRunningPs1 {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration,
        [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$action,
        [parameter(Mandatory = $false,
            ValueFromRemainingArguments = $true)]
        [String[]]
        $hints
    )
    $sshInvoker = Get-SshInvoker -configuration $configuration

    $cfn = Split-UniversalPath -Path $ConfigFile

    $toServerConfigFile = Join-UniversalPath -Path $configuration.ServerSide.ScriptDir -ChildPath $cfn
    $entryPoint = Join-UniversalPath -Path $configuration.ServerSide.ScriptDir -ChildPath $configuration.ServerSide.EntryPoint
    
    $rcmd = "pwsh -f {0} -action {1} -ConfigFile {2} {3} {4}" -f $entryPoint, $action, $toServerConfigFile, (Get-Verbose), ($hints -join ' ')
    $rcmd | Out-String | Write-Verbose
    $sshInvoker.Invoke($rcmd)
}