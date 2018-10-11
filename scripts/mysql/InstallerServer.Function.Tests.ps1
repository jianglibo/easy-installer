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
}


Describe "install" {
    it "should return already installed." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
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