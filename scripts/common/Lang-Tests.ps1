Describe "global scope" {
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

}

Describe "global scope 1" {
    it "can accessable variables by argumentlist job block." {
        $hash = [hashtable]::Synchronized(@{v=0})
        
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