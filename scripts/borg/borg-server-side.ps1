param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install",
        "Uninstall",
        "InitializeRepo",
        "Archive",
        "Prune",
        "DownloadPublicKey")]
    [string]$Action,
    [parameter(Mandatory = $false)][switch]$NotCleanUp,
    [parameter(Mandatory = $false,
        ValueFromRemainingArguments = $true)]
    [String[]]
    $hints
)

$vb = $PSBoundParameters.ContainsKey('Verbose')
if ($vb) {
    $PSDefaultParameterValues['*:Verbose'] = $true
}

"hints is: $($hints -join ' ')" | Write-Verbose

$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent

$ConfigFile = $here | Join-Path -ChildPath "config.json"

$ConfigFile | Write-Verbose

# directories are flatten.
. (Join-Path -Path $here -ChildPath "common-util.ps1")
. (Join-Path -Path $here -ChildPath "borg-server-function.ps1")

$configuration = Get-Configuration -ConfigFile $ConfigFile -ServerSide
$osConfig = $configuration.OsConfig


Get-ChildItem -Path (Join-UniversalPath -Path $osConfig.ServerSide.ScriptDir -ChildPath "*.ps1") |
    Select-Object -ExpandProperty FullName |
    Where-Object {$_ -ne $myself} |
    ForEach-Object {
    . $_
}
try {
    switch ($Action) {
        "Install" {
            Install-Borg
            break
        }
        "Uninstall" {
            Uninstall-Borg
            break
        }
        "InitializeRepo" {
            Initialize-BorgRepo
            break
        }
        "Archive" {
            New-BorgArchive
            break
        }
        "Prune" {
            Invoke-BorgPrune
            break
        }
        "DownloadPublicKey" {
            Get-OpenSSLPublicKey
            break
        }
        Default {
            $configuration | ConvertTo-Json -Depth 10
        }
    }
}
finally {
    $PSDefaultParameterValues['*:Verbose'] = $false
}