Describe "global scope" {
    $plainfile = Join-Path $TestDrive "plain.txt"
    it "cannot accessable global variables from job block." {
        $Global:v = 0
        $job = Start-Job -ScriptBlock {
            while ($true) {
                $Global:v += 1
                Start-Sleep -Seconds 1
            }
        }

        Start-Sleep -Seconds 3
        $Global:v | Out-Host
        $job | Out-Host
        Stop-Job -Job $job
        $job | Out-Host
        # cannot change the global value.
        $Global:v | Should -Be 0
    }

    it "is true, that try catch in a same scope." {
        try {
            $a = 1
        }
        catch {
            
        }
        finally {
            $a | Should -Be 1   
        }

    }

}

Describe "global scope 1" {
    it "can accessable variables by argumentlist job block." {
        $hash = [hashtable]::Synchronized(@{v = 0})
        
        $job = Start-Job -ScriptBlock {
            Param($ht)
            while ($true) {
                $ht.v += 1
                $ht
                Start-Sleep -Seconds 1
            }
            
        } -ArgumentList $hash

        Start-Sleep -Seconds 3
        $hash | Out-Host
        $job | Out-Host
        Receive-Job -Job $job | Out-Host
        Stop-Job -Job $job
        $job | Out-Host
        # cannot change the global value.
        $hash.v | Should -Be 0
        Receive-Job -Job $job
    }

}

Describe "file path" {
    it "should get right path." {
        try {
            $d = New-TemporaryDirectory
            $t = $d | Join-Path -ChildPath "config.json"

            $t | Should -BeOfType [string]
            $t | Should -Match '::'
            "abc" | Out-File $t
            Resolve-Path $t | Select-Object -ExpandProperty ProviderPath | Should -Not -Match '::'
        }
        finally {
            Remove-Item -Path $d -Recurse -Force
        }
    }
}

Describe "switch case" {
    it "should handle expression branch" {
        $y = 0
        $x = "yw"
        switch ($x) {
            ({($PSItem -eq 'yw') -or ($PSItem -eq 'yy')}) { 
                $y = 5
             }
            Default {}
        }
        $y | Should -Be 5

        $y = 0
        $x = "yw"
        switch ($x) {
            ({$PSItem -in "k","yw"}) { 
                $y = 5
             }
            Default {}
        }
        $y | Should -Be 5
    }
}