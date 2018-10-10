param (
    [parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "Echo")]
    [string]$Action,
    [parameter(Mandatory = $true, Position = 1)]
    [string]$ConfigFile,
    [parameter(Mandatory = $false,
        ValueFromRemainingArguments = $true)]
    [String[]]
    $hints
)

process { 
    $vb = $PSBoundParameters.ContainsKey('Verbose')
    if ($vb) {
        $PSDefaultParameterValues['*:Verbose'] = $true
    }

    $myself = $MyInvocation.MyCommand.Path
    $here = $myself | Split-Path -Parent

    . (Join-Path -Path $here -ChildPath "common-util.ps1")

    $configuration = Get-Configuration -ConfigFile $ConfigFile -ServerSide

    Get-ChildItem -Path (Join-UniversalPath -Path $configuration.ServerSide.ScriptDir -ChildPath "*.ps1") |
        Select-Object -ExpandProperty FullName |
        Where-Object {$_ -ne $myself} |
        ForEach-Object {
        . $_
    }

    switch ($Action) {
        "Echo" {
            $hints -join ' '
            break
        }
        Default {
            $configuration | ConvertTo-Json
        }
    }
}