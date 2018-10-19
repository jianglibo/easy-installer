class Aclass {
    [object]$json

    Aclass($json) {
        $this.json = $json
    }
}

Describe "customobject wrapper class." {
    it "should like dict." {
        $s = '{a: 1,b: {c: "kkv"}}'
        $json = $s | ConvertFrom-Json
        $json | Should -BeOfType [PSCustomObject]
        Add-Member -InputObject $json -MemberType Method -Name aplusone -Value {
            $this.a + 1
        }
    }
}