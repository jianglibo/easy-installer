$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"
. "$here\common-util.ps1"

$kv = Get-Content "$here\common-util.t.json" | ConvertFrom-Json


Describe "SshInvoker pwsh" {
    it "should right" {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $o | Should -Not -BeNullOrEmpty
        $o.sshStr | Should -BeLike "ssh -i *"
    }
}

Describe "SshInvoker" {
    $parent = "TestDrive:\folder"

    $noversionFolder = "${parent}\noversions\nov"
    New-Item -ItemType Directory -Path $noversionFolder | Out-Null

    $srcFolder = "${parent}\src"
    New-Item -ItemType Directory -Path $srcFolder | Out-Null

    $kkvFileInSrcFolder = Join-Path -Path $srcFolder -ChildPath "kkv.txt"
    "abc" | Out-File $kkvFileInSrcFolder 

    It "shoud create SshInvoker Object." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $o | Should -Not -BeNullOrEmpty
        $o.sshStr | Should -BeLike "ssh -i *"
    }
    It "shoud invoke bash command." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $r = $o.InvokeBash("echo a", $false);
        $o.result | Should -Be $r
        $o.ExitCode | Should -Be 0
        $r | Should -Be "a"
    }
    It "shoud handle command not found." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $r = $o.InvokeBash("echo001 a", $true);
        $o.IsCommandNotFound() | Should -BeTrue
    }

    It "shoud contains new lines." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $r = $o.InvokeBash("ls -lh /", $true)

        "a" | should -BeOfType [string]
        $r | Should -BeOfType [string] # first item.
        $r.Count |Should -BeGreaterThan 2
    }
}

Describe "SshInvoker ScpFrom" {
    $tg = Join-Path $TestDrive 'folder'
    $tf = Join-Path $TestDrive -ChildPath "tf"
    $tf1 = Join-Path $TestDrive -ChildPath "tf1"
    $tf2 = Join-Path $TestDrive -ChildPath "tf2"
    BeforeEach {
        $remoteFolderNoEndSlash = '/tmp/folder'
        $sshInvoker = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
    }

    It "should copy one file." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        $r = $sshInvoker.ScpFrom("/var/lib/mysql/hm-log-bin.index", $tg, $false)
        Test-Path -Path $r| Should -BeTrue
    }
    It "should copy files by command." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        New-Item -Path $tf2 -ItemType Directory | Out-Null
        [array]$r = Copy-FilesFromServer -RemotePathes "/var/lib/mysql/hm-log-bin.000008", "/var/lib/mysql/hm-log-bin.000009" -LocalDirectory $tf2 -configuration @{HostName=$kv.HostName;IdentityFile=$kv.ifile}
        $r.Count | Should -Be 2
        $r | Test-Path -PathType Leaf | Should -BeTrue
    }

    It "should copy files." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        New-Item -Path $tf -ItemType Directory | Out-Null
        $r = $sshInvoker.ScpFrom(@("/var/lib/mysql/hm-log-bin.000008", "/var/lib/mysql/hm-log-bin.000009"), $tf)
        $r | Test-Path -PathType Leaf | Should -BeTrue
    }

    It "should copy files with space in name." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        New-Item -Path $tf1 -ItemType Directory | Out-Null
        $r = $sshInvoker.ScpFrom(@("'/root/a b/1.txt'", "'/root/a b/2.txt'"), $tf1)
        $r | Test-Path -PathType Leaf | Should -BeTrue
    }
}

Describe "SshInvoker ScpTo" {
    $parent = Join-Path $TestDrive 'folder'

    $noversionFolder = "${parent}\noversions\nov"
    New-Item -ItemType Directory -Path $noversionFolder | Out-Null

    $srcFolder = "${parent}\src"
    New-Item -ItemType Directory -Path $srcFolder | Out-Null

    $kkvFileInSrcFolder = Join-Path -Path $srcFolder -ChildPath "kkv.txt"
    "abc" | Out-File $kkvFileInSrcFolder 

    $kkvFileInSrcFolder1 = Join-Path -Path $srcFolder -ChildPath "kkv1.txt"
    "abc" | Out-File $kkvFileInSrcFolder1 

    BeforeEach {
        $remoteFolderNoEndSlash = '/tmp/folder'
        $sshInvoker = [SshInvoker]::new($kv.HostName, $kv.ifile, $kv.SshPort)
        $sshInvoker.Invoke("rm -rvf ${remoteFolderNoEndSlash}")
        $sshInvoker.Invoke("mkdir -p ${remoteFolderNoEndSlash}")
    }

    It "should throw exception." {
        {$sshInvoker.ScpTo($kkvFileInSrcFolder + "kkv", $remoteFolderNoEndSlash, $true)} | Should -Throw "doesn't exist"
    }

    It "should handle ScpTo to unreachable destination." {
        { $sshInvoker.ScpTo($kkvFileInSrcFolder, "$remoteFolderNoEndSlash/aa/bb/cc", $true)} | Should -Throw "scp: /tmp/folder/aa/bb/cc: No such file or directory"
        # $uploladed | Should -Be "/tmp/folder/aa/bb/cc/kkv.txt"
        # $sshInvoker.isFileExists("/tmp/folder/aa/bb/cc/kkv.txt") | Should -BeTrue
    }

    It "should ScpTo a file to target no end slash." {
        $sshInvoker.ScpTo($kkvFileInSrcFolder, $remoteFolderNoEndSlash, $true)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should ScpTo a file to target with end slash." {
        $sshInvoker.ScpTo($kkvFileInSrcFolder, $remoteFolderNoEndSlash + '/', $true)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should ScpTo a file to target with another name." {
        $sshInvoker.ScpTo($kkvFileInSrcFolder, $remoteFolderNoEndSlash + '/aaa.txt', $false)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeFalse

        $rr = "${remoteFolderNoEndSlash}/aaa.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should ScpTo a folder to target no lastslash." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.ScpTo($srcFolder, $remoteFolderNoEndSlash, $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should ScpTo a folder to target with lastslash." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.ScpTo($srcFolder, $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }
    It "should ScpTo a folder to target with asterisk." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.ScpTo($parent + '/*', $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue

        $rr = "${remoteFolderNoEndSlash}/noversions/nov"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }
    It "should ScpTo 2 files to target folder." {
        $sshInvoker.ScpTo("$kkvFileInSrcFolder $kkvFileInSrcFolder1", $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue

        $rr = "${remoteFolderNoEndSlash}/kkv1.txt"
        $rr = $sshInvoker.isFileExists($rr) 
        $rr | Should -BeTrue
    }
}

