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

function Download-SoftwarePackages {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )
    $dl = Join-Path -Path $PWD -ChildPath "downloads"
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

function Get-Configuration {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$MyDir,
        [Parameter(Mandatory = $true, Position = 1)][string]$ConfigFile
    )
    $vcf = Resolve-Path -Path $ConfigFile -ErrorAction SilentlyContinue

    if (-not $vcf) {
        $m = "ConfigFile ${ConfigFile} doesn't exists."
        Write-ParameterWarning -wstring $m
        return
    }
    $c = Get-Content -Path $vcf | ConvertFrom-Json

    if ($c.IdentityFile) {
        if (-not (Test-Path -Path $c.IdentityFile -PathType Leaf)) {
            Write-ParameterWarning -wstring "IdentityFile property in $vcf point to an unexist file."
            return
        } else {
            return $c
        }
    }
    
    if (-not $c.Password) {
        Write-ParameterWarning -wstring "Neither IdentityFile Nor Password property exists in ${vcf}."
        return
    }

    $c
}

function Write-ParameterWarning {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$wstring
    )
    $stars = (1..$wstring.Length | ForEach-Object {'*'}) -join ''
    "`n`n{0}`n`n{1}`n`n{2}`n`n" -f $stars,$wstring,$stars | Write-Warning
}
# PS C:\>$Secure = Read-Host -AsSecureString
# PS C:\>$Encrypted = ConvertFrom-SecureString -SecureString $Secure -Key (1..16)
# PS C:\>$Encrypted | Set-Content Encrypted.txt
# PS C:\>$Secure2 = Get-Content Encrypted.txt | ConvertTo-SecureString -Key (1..16)