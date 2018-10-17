$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$fixture = "${here}\fixtures\mysql-community.repo"

".\SshInvoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

function Assert-Enabled {
    param (
        [string]$RepoPath,
        [string]$ToBeEabled
    )
    $enabled = Get-Content $changed | ForEach-Object -Begin {
        $currentVersion = ""
    } -Process {
        if (($_ -match '^\[.*\]$')) {
            $currentVersion = $Matches[0]
        }
        else {
            if (($_ -match '^enabled=(0|1)$')) {
                if ($Matches[1] -eq "1") {
                    $currentVersion
                }
            }
        }
    }
    $ToBeEabled -in $enabled
}

Describe "manual" {
    $repofile = Join-Path $TestDrive "mysql-community.repo"
    $changed = Join-Path $TestDrive "changed.repo"
    Copy-Item -Path $fixture -Destination $repofile
    it "should change active version" {
        Enable-RepoVersion -RepoFile $repofile -Version 55 | Out-File -FilePath $changed
        Assert-Enabled -RepoPath $changed -ToBeEabled "[mysql55-community]" | Should -BeTrue
        Assert-Enabled -RepoPath $changed -ToBeEabled "[mysql56-community]" | Should -BeFalse

        Enable-RepoVersion -RepoFile $repofile -Version 56 | Out-File -FilePath $changed
        Assert-Enabled -RepoPath $changed -ToBeEabled "[mysql55-community]" | Should -BeFalse
        Assert-Enabled -RepoPath $changed -ToBeEabled "[mysql56-community]" | Should -BeTrue
        do {

        } while ($false)
    }

    it "should alter hashtable" {
        $ht = @{a=@{b=@{c=1}}}
        $ht1 = Get-ChangedHashtable -customob $ht -OneLevelHashTable @{"a.b"=2}
        $ht.a.b |Should -Be 2
        $ht1.a.b |Should -Be 2

        $configuration = Get-DemoConfiguration -HerePath $here

        $configuration.SwitchByOs.centos.ServerSide.EntryPoint | Should -Be "InstallerServer.ps1"

        Get-ChangedHashtable -customob $configuration -OneLevelHashTable @{"SwitchByOs.centos.ServerSide.EntryPoint"=55}
        $configuration.SwitchByOs.centos.ServerSide.EntryPoint | Should -Be 55

        Get-ChangedHashtable -customob $configuration -OneLevelHashTable @{"SwitchByOs.centos.Softwares[0].LocalName"="ln"}
        $configuration.SwitchByOs.centos.Softwares[0].LocalName | Should -Be "ln"

    }

    it "should get new config file" {
        # $f = Get-ConfigFileInTestDriver $here
        # $ht = Get-Content -Path $f | ConvertFrom-Json
        # $ht.SwitchByOs.centos.Softwares[0].LocalName | Should -BeNullOrEmpty

        $f = Get-ConfigFileInTestDriver $here -OneLevelHashTable @{"SwitchByOs.centos.Softwares[0].LocalName"="ln"}

        $ht = Get-Content -Path $f | ConvertFrom-Json
        $ht.SwitchByOs.centos.Softwares[0].LocalName | Should -Be "ln"


        $ht.MysqlPassword | Should -Be "123456"
        $f = Get-ConfigFileInTestDriver $here -OneLevelHashTable @{"MysqlPassword"="567"}
        $ht = Get-Content -Path $f | ConvertFrom-Json
        $ht.MysqlPassword | Should -Be "567"
    }
}


Describe "install" {
    it "should return already installed." {
        $ht = Copy-TestPsScriptToServer -HerePath $here -Verbose
        $ht.ConfigFile | Out-Host
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action Install 57
        $r | Should -Be 'AlreadyInstalled'
    }
}

Describe "getmycnf" {
    it "should return already installed." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action GetMycnf
        $r | Should -Be '/etc/my.cnf'
    }
}

Describe "get mysql variables" {
    it "should return variables hashtable." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "auto_increment_offset"
        $r = $r | ConvertFrom-Json
        $r.value | Should -Be '1'

        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "auto_increment_offset1"
        $r | Should -BeFalse

        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "datadir"
        $r = $r | ConvertFrom-Json
        $r.value | Should -Be '/var/lib/mysql/'

    }
}

Describe "uninstall mysql access denied." {
    it "should denied." {
        $f = Get-ConfigFileInTestDriver -HerePath $here -OneLevelHashTable @{MysqlPassword="bbc"}
        $ht = Copy-TestPsScriptToServer -HerePath $here -ConfigFile $f
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $f -Action uninstall -notCombineError
        $r | should -Be 'Mysql Access Denied.'
    }
}

Describe "uninstall mysql successly." {
    it "should uninstall." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -Action uninstall -notCombineError
        $r | should -Be 'Uninstall successly.'
    }
}