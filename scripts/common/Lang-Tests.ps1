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
            ( {($PSItem -eq 'yw') -or ($PSItem -eq 'yy')}) { 
                $y = 5
            }
            Default {}
        }
        $y | Should -Be 5

        $y = 0
        $x = "yw"
        switch ($x) {
            ( {$PSItem -in "k", "yw"}) { 
                $y = 5
            }
            Default {}
        }
        $y | Should -Be 5
    }
}

function Test-NullParameter {
    Param(
        [string]$s = $null
    )

    if ($s -eq $null) {
        "null"
    }
    elseif ($s -eq "") {
        "empty"
    }
    else {
        $s
    }
}

Describe "null parameter." {
    it "should handle null" {
        Test-NullParameter | Should -Be "empty"
        Test-NullParameter -s ""| Should -Be "empty"
        Test-NullParameter -s "a"| Should -Be "a"
    }
}

function BreakInPorcess {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $InputObject
    )
    Begin
    {"a"}

    process {
        $_
        if ($_ -eq 4)
        {break}
    }

    End
    {"b"}
}

function ContinueInPorcess {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $InputObject
    )
    Begin
    {"a"}

    process {
        if ($_ -gt 3) {
            continue
        }
        $_
    }

    End
    {"b"}
}

function InputObjectParameters {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $InputObject
    )
    Begin
    {"a"}
    process {
        $_
    }

    End
    {"b"}
}

Describe "break or continue the pipeline" {
    it "should break" {
        $result = 1..10 | BreakInPorcess | Out-Host
        $result | Should -Be 'z'
    }

    it "should continue" {
        1..10 | ContinueInPorcess | Out-Host
    }

    it "input objects should work by pipe" {
        1..2 | InputObjectParameters | Should -Be 'a',1,2,'b'
    }

    it "input objects should work by parameter" {
        InputObjectParameters -InputObject @('1','2') | Should -Be 'a',1,2,'b'
    }
}

Describe "list of list" {
    it "should handle arrays" {
        @(1,2),@(3,4) | Measure-Object | Out-Host

        foreach ($item in "abc") {
            $item | Out-Host
        }
    }
}
