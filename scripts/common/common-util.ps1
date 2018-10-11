function Split-Url {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter()]
        [ValidateSet("Container", "Leaf")]
        [string]$ItemType = "Leaf"
    )

    $parts = $Url -split '://', 2

    if ($parts.Count -eq 2) {
        $hasProtocal = $true
        $beforeProtocol = $parts[0]
        $afterProtocol = $parts[1]
    }
    else {
        $hasProtocal = $false
        $afterProtocol = $parts[0]
    }
    $idx = $afterProtocol.LastIndexOf('/')
    if ($idx -eq -1) {
        if ($ItemType -eq "Leaf") {
            ''
        }
        else {
            $Url
        }
    }
    else {
        if ($ItemType -eq "Leaf") {
            $afterProtocol.Substring($idx + 1)
        }
        else {
            $afterProtocol = $afterProtocol.Substring(0, $idx + 1)
            if ($hasProtocal) {
                "${beforeProtocol}://${afterProtocol}"
            }
            else {
                $afterProtocol
            }
        }
    }
}


function Get-Configuration {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$ConfigFile,
        [Parameter()][switch]$ServerSide
    )
    $vcf = Resolve-Path -Path $ConfigFile -ErrorAction SilentlyContinue

    if (-not $vcf) {
        $m = "ConfigFile ${ConfigFile} doesn't exists."
        Write-ParameterWarning -wstring $m
        return
    }
    $c = Get-Content -Path $vcf | ConvertFrom-Json

    if (-not $ServerSide) {
        if ($c.IdentityFile) {
            if (-not (Test-Path -Path $c.IdentityFile -PathType Leaf)) {
                Write-ParameterWarning -wstring "IdentityFile property in $vcf point to an unexist file."
                return
            }
            else {
                return $c
            }
        }
        
        if (-not $c.ServerPassword) {
            Write-ParameterWarning -wstring "Neither IdentityFile Nor ServerPassword property exists in ${vcf}."
            return
        }
    }
    $c
}
function Join-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path,
        [Parameter(Mandatory = $true, Position = 1)][string]$ChildPath
    )
    $sanitizedParent = sanitizePath -Path $Path
    $pp = $sanitizedParent.sanitized
    $sp = $sanitizedParent.separator
    $sanitizedChild = sanitizePath -Path $ChildPath
    $cp = $sanitizedChild.sanitized
    $sc = $sanitizedChild.separator

    if ($sp -ne $sc) {
        if ($sc -eq '\') {
            $sc = '\\'
        }
        $cp = $cp -replace $sc, $sp
    }

    if ($cp.StartsWith($sp)) {
        $cp = $cp.Substring(1)
    }
    "${pp}${sp}${cp}"
}

function sanitizePath {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$Path
    )
    $separator = '\'
    $ptn = '\\+'
    if ($Path.Contains("/")) {
        if ($Path.Contains("\")) {
            $Path = $Path -replace "\\", "/"
        }
        $separator = '/';
        $ptn = '/+'
    }
    $Path = $Path -replace $ptn, $separator
    if ($Path.EndsWith($separator)) {
        $Path = $Path.Substring(0, $Path.Length - 1)
    }
    @{sanitized = $Path; separator = $separator}
}
function Split-UniversalPath {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$Path,
        [switch]$Parent
    )
    $sanitized = sanitizePath -Path $Path
    $Path = $sanitized.sanitized
    $separator = $sanitized.separator

    $idx = $Path.LastIndexOf($separator)
    if ($idx -ne -1) {
        if ($Parent) {
            $Path = $Path.Substring(0, $idx)
        }
        else {
            $Path = $Path.Substring($idx + 1)
        }
    }
    $Path
}

function Get-Verbose {
    $b = [bool](Write-Verbose ([String]::Empty) 4>&1)
    if ($b) {
        "-Verbose"
    }
    else {
        ""
    }
}

function Write-ParameterWarning {
    param (
        [Parameter(Mandatory = $true, Position = 0)][string]$wstring
    )
    $stars = (1..$wstring.Length | ForEach-Object {'*'}) -join ''
    "`n`n{0}`n`n{1}`n`n{2}`n`n" -f $stars,$wstring,$stars | Write-Warning
}

function Test-SoftwareInstalled {
    param (
        [Parameter(Mandatory = $true, Position = 0)]$configuration
    )

    $idt = $configuration.ServerSide.InstallDetect
    $idt.command | Write-Verbose
    $idt.expect | Write-Verbose
    $idt.unexpect | Write-Verbose
    $r = Invoke-Expression -Command $idt.command
    $r | Write-Verbose
    if ($idt.expect) {
        $idt.expect | Write-Verbose
        $r -match $idt.expect
    } else {
        -not ($r -match $idt.unexpect)
    }
}