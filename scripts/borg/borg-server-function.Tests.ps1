$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"
. "$here\borg-client-function.ps1"

".\ssh-invoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

Describe "install" {
    it "should install borg." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $PSDefaultParameterValues['*:Verbose'] = $true
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action Install
        $r | Receive-LinesFromServer | Should -Be 'Install Success.'
    }
}

Describe "uninstall borg successly." {
    it "should uninstall." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -Action uninstall -notCombineError
        $r | Receive-LinesFromServer | should -Be 'Uninstall successly.'
    }
}

Describe "init borg repo successly." {
    it "should init repo." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -Action InitializeRepo -notCombineError
        $r | Receive-LinesFromServer | should -Be 'SUCCESS'
    }
}

Describe "new borg archive successly." {
    it "should create new borg archive." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -Action Archive
        $r | Out-Host
        $r = $r | Receive-LinesFromServer | ConvertFrom-Json
        $r.archive.stats.compressed_size | should -BeTrue
    }
}

Describe "new borg prune successly." {
    it "should prune borg archive." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -Action Prune
        $r | Out-Host
        [array]$r = $r | Receive-LinesFromServer
        $r.Count | should -GT 0
    }
}

Describe "download borg repo." {
    it "should download borg repo." {
        Get-Configuration -ConfigFile ($here | Join-Path -ChildPath "demo-config.1.json")
        $r = Copy-BorgRepoFiles
        $r | Out-Host
        $r.total | Out-Host
        $r.copied.Length | Should -GT 0
    }
}

Describe "copy changed files." {
    it "should copy changed files." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        Get-Configuration -ConfigFile ($here | Join-Path -ChildPath "demo-config.1.json")
        $Error.Clear()
        $repo = Get-MaxLocalDir
        if (Test-Path -Path $repo) {
            Remove-Item -Recurse -Force -Path $repo
        }
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo
        $r | ConvertTo-Json -Depth 10 | Out-Host
        $r.total.Length | Should -Be $r.copied.Length
        # $r.total.files.value | Should -BeNullOrEmpty
        # [array]$ers = $Error | Where-Object FullyQualifiedErrorId -Like 'SCP_FROM,*'
        # $ers.Count | Should -BeGreaterThan 0
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo -OnlySum -Json
        $r | Out-Host
        $r.copied.Count | Should -Be 0

        $repo = Get-MaxLocalDir -Next
        if (Test-Path -Path $repo) {
            Remove-Item -Recurse -Force -Path $repo
        }
        $r = Copy-ChangedFiles -RemoteDirectory '/etc/NetworkManager' -LocalDirectory $repo
        $r | ConvertTo-Json | Out-Host
        $r.copied.Count | Should -GT 0
    }
}