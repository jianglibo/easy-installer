$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

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