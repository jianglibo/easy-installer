$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

. "$here\mysql-clientside.ps1"

$fixture = "${here}\fixtures\mysql-community.repo"

".\ssh-invoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
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

        $configuration.SwitchByOs.centos.ServerSide.EntryPoint | Should -Be "installer-server.ps1"

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


        $f = Get-ConfigFileInTestDriver $here -OneLevelHashTable @{"MysqlPassword"="567"}
        $ht = Get-Content -Path $f | ConvertFrom-Json
        $ht.MysqlPassword | Should -Be "567"
    }
}


Describe "install" {
    # it "should return already installed." {
    #     $ht = Copy-TestPsScriptToServer -HerePath $here 
    #     $ht.ConfigFile | Out-Host
    #     $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action Install 57
    #     $r | Should -Be 'AlreadyInstalled'
    # }

    it "should install mysql." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $PSDefaultParameterValues['*:Verbose'] = $true
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action Install 57
        $r | Should -Be 'AlreadyInstalled'
    }
}

Describe "update mysql password." {
    it "should update password." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action UpdateMysqlPassword
        $r | Should -Be '/etc/my.cnf'
    }
}

Describe "getmycnf" {
    it "should return already installed." {
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -configuration $ht.configuration -ConfigFile $ht.ConfigFile -action GetMycnf
        $r | Should -Be '/etc/my.cnf'
    }
}

Describe "should convert namevalue pair" {
    it "should convert" {
        $r = @{name='a';value=2},@{name='b';value=3} | ConvertFrom-NameValuePair
        $r.a | Should -Be 2
        $r.b | Should -Be 3
    }
}
Describe "get mysql variables" {
    it "should return variables hashtable." {
        $PSDefaultParameterValues['*:Verbose'] = $false
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "auto_increment_offset" "datadir"
        $r | Out-Host
        $r = $r | ConvertFrom-Json | ConvertFrom-NameValuePair
        $r | Out-Host
        $r.auto_increment_offset | Should -Be '1'
        $r.datadir | Should -Be '/var/lib/mysql/'

        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "auto_increment_offset1"
        $r | Out-Host
        $r | Should -BeFalse

        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action GetVariables -notCombineError "datadir"
        $r | Out-Host
        $r = $r | ConvertFrom-Json | ConvertFrom-NameValuePair
        $r.datadir | Should -Be '/var/lib/mysql/'

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

Describe "enable logbin" {
    it "should enable logbin" {
        $PSDefaultParameterValues['*:Verbose'] = $true
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action EnableLogbin
        $r | Out-Host
        $rr = $r | Receive-LinesFromServer
        $rr | Should -BeNullOrEmpty
    }
}

Describe "mysql extra file" {
    it "should create" {
        $PSDefaultParameterValues['*:Verbose'] = $false
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action MysqlExtraFile -NotCleanUp
        $r | Out-Host

        $sshinvoker = Get-SshInvoker
        $r = $sshinvoker.Invoke("cat $r")
        $r | Where-Object {$_ -eq '[client]'} | should -BeTrue
        $r | Where-Object {$_ -eq 'user=root'} | should -BeTrue
    }
}

Describe "dump mysql" {
    $df = Join-Path $TestDrive "dump.sql"
    it "should dump" {
        $PSDefaultParameterValues['*:Verbose'] = $false
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action MysqlDump
        $r | Out-Host
        $ht = $r | Receive-LinesFromServer | ConvertFrom-ListFormatOutput
        $ht | Out-Host
        $ht.Path | Should -Be $Global:configuration.DumpFilename
        [SshInvoker]$sshinvoker = Get-SshInvoker
        $sshinvoker.ScpFrom($ht.Path, $df, $false)
        (Get-FileHash -Path $df).Hash | Should -Be $ht.Hash
        # Get-Content -Path $df | Out-Host
    }

    it "should dump and verify hash" {
        $PSDefaultParameterValues['*:Verbose'] = $false
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action MysqlDump
        $ht = $r | Receive-LinesFromServer | ConvertFrom-ListFormatOutput
        $tdump = Copy-MysqlDumpFile -RemoteDumpFileWithHashValue $ht
        Test-Path -Path $tdump -PathType Leaf | Should -BeTrue
    }
}

Describe "flush mysql" {
    $idxfolder = Join-Path $TestDrive "localdir"
    it "should flush" {
        $PSDefaultParameterValues['*:Verbose'] = $false
        $ht = Copy-TestPsScriptToServer -HerePath $here
        $r = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action MysqlFlushLogs
        $ht = $r | Receive-LinesFromServer | ConvertFrom-ListFormatOutput
        Copy-MysqlLogFiles -RemoteLogFilesWithHashValue $ht

        $maxb = Get-MysqlMaxDump

        $idxfile = Join-Path -Path $maxb -ChildPath 'logbin.index'

        [array]$lines = Get-Content -Path $idxfile

        [array]$files = Get-ChildItem -Path $maxb -Exclude '*.index'

        $lines.Count | Should -Be $files.Count
    }
}