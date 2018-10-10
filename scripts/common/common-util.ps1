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
        } else {
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
            } else {
                $afterProtocol
            }
        }
    }
}
