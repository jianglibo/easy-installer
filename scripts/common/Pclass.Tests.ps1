class Aclass {
    [object]$json

    Aclass($json) {
        $this.json = $json
    }
}



Describe "env." {
    $plainfile = Join-Path $TestDrive "plain.ps1"
    it "should change env in process." {
        '$env:abc=2' | Out-File $plainfile
        $env:abc = 1
        $j = Invoke-Command -FilePath $plainfile
        $j | Out-Host
        $env:abc | Should -Be 2
    }
}


Describe "customobject wrapper class." {
    it "should like dict." {
        $s = '{a: 1,b: {c: "kkv"}}'
        $json = $s | ConvertFrom-Json
        $json | Should -BeOfType [PSCustomObject]
        $json | Add-Member @{xx=1}
        $json.xx | Should -Be 1

        $json | Add-Member yy 2
        $json.yy | Should -Be 2

        $json | Add-Member -NotePropertyMembers @{c1='a';c2=2}
        $json.c1 | Should -Be 'a'
        $json.c2 | Should -Be 2

        $json | Add-Member -MemberType ScriptMethod -Name sum -Value {
            $this.xx + $this.yy
        }
        $json.sum() | Should -Be 3

        $json | Add-Member -MemberType ScriptProperty -Name psum -Value {
            $this.xx + $this.yy
        }
        $json.psum | Should -Be 3

    }
}