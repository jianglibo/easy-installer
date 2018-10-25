$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"

$kv = Get-Content "$here\common-util.t.json" | ConvertFrom-Json

Describe "SshInvoker" {
    $parent = "TestDrive:\folder"

    $noversionFolder = "${parent}\noversions\nov"
    New-Item -ItemType Directory -Path $noversionFolder

    $srcFolder = "${parent}\src"
    New-Item -ItemType Directory -Path $srcFolder

    $kkvFileInSrcFolder = Join-Path -Path $srcFolder -ChildPath "kkv.txt"
    "abc" | Out-File $kkvFileInSrcFolder 

    It "shoud create SshInvoker Object." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile)
        $o | Should -Not -BeNullOrEmpty
        $o.sshStr | Should -BeLike "ssh -i *"
    }
    It "shoud invoke bash command." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile)
        $r = $o.InvokeBash("echo a", $false);
        $o.result | Should -Be $r
        $o.ExitCode | Should -Be 0
        $r | Should -Be "a"
    }
    It "shoud handle command not found." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile)
        $r = $o.InvokeBash("echo001 a", $true);
        $o.IsCommandNotFound() | Should -BeTrue
    }

    It "shoud contains new lines." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile)
        $r = $o.InvokeBash("ls -lh /", $true)

        "a" | should -BeOfType [string]
        $r | Should -BeOfType [string] # first item.
        $r.Count |Should -BeGreaterThan 2
    }
}

Describe "SshInvoker ScpTo" {
    $parent = Join-Path $TestDrive 'folder'

    $noversionFolder = "${parent}\noversions\nov"
    New-Item -ItemType Directory -Path $noversionFolder

    $srcFolder = "${parent}\src"
    New-Item -ItemType Directory -Path $srcFolder

    $kkvFileInSrcFolder = Join-Path -Path $srcFolder -ChildPath "kkv.txt"
    "abc" | Out-File $kkvFileInSrcFolder 

    $kkvFileInSrcFolder1 = Join-Path -Path $srcFolder -ChildPath "kkv1.txt"
    "abc" | Out-File $kkvFileInSrcFolder1 

    BeforeEach {
        $remoteFolderNoEndSlash = '/tmp/folder'
        $sshInvoker = [SshInvoker]::new($kv.HostName, $kv.ifile)
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

