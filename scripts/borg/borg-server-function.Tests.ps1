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
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action Install 57
        $r | Should -Be 'AlreadyInstalled'
    }
}

Describe "uninstall borg successly." {
    it "should uninstall." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -Action uninstall -notCombineError
        $r | should -Be 'Uninstall successly.'
    }
}