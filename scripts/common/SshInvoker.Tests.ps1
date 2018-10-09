# using module '.\SshInvoker.psm1'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\deploy-util.ps1"
. "$here\$sut"

$kv = Get-Content "$here\properties-for-test.json" | ConvertFrom-Json

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
        $r = $o.InvokeBash("echo a");
        $o.result | Should -Be $r
        $o.ExitCode | Should -Be 0
        $r | Should -Be "a"
    }
    It "shoud handle command not found." {
        $o = [SshInvoker]::new($kv.HostName, $kv.ifile)
        $r = $o.InvokeBash("echo001 a");
        $o.IsCommandNotFound() | Should -BeTrue
    }
}

Describe "SshInvoker scp" {
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
        {$sshInvoker.scp($kkvFileInSrcFolder + "kkv", $remoteFolderNoEndSlash, $true)} | Should -Throw "doesn't exist"
    }

    It "should handle scp to unreachable destination." {
        $uploladed = $sshInvoker.scp($kkvFileInSrcFolder, "$remoteFolderNoEndSlash/aa/bb/cc", $true)
        $uploladed | Should -Be "/tmp/folder/aa/bb/cc/kkv.txt"
        $sshInvoker.isFileExists("/tmp/folder/aa/bb/cc/kkv.txt") | Should -BeTrue
    }

    It "should scp a file to target no end slash." {
        $sshInvoker.scp($kkvFileInSrcFolder, $remoteFolderNoEndSlash, $true)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should scp a file to target with end slash." {
        $sshInvoker.scp($kkvFileInSrcFolder, $remoteFolderNoEndSlash + '/', $true)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should scp a file to target with another name." {
        $sshInvoker.scp($kkvFileInSrcFolder, $remoteFolderNoEndSlash + '/aaa.txt', $false)
        $fn = Split-Path -Path $kkvFileInSrcFolder -Leaf
        $fn | Should -Be 'kkv.txt'
        $rr = "${remoteFolderNoEndSlash}/${fn}"
        $sshInvoker.isFileExists($rr) | Should -BeFalse

        $rr = "${remoteFolderNoEndSlash}/aaa.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should scp a folder to target no lastslash." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.scp($srcFolder, $remoteFolderNoEndSlash, $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }

    It "should scp a folder to target with lastslash." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.scp($srcFolder, $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }
    It "should scp a folder to target with asterisk." {
        # xx/src -> /tmp/folder, => /tmp/folder/src/kkv.txt
        $sshInvoker.scp($parent + '/*', $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/src/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue

        $rr = "${remoteFolderNoEndSlash}/noversions/nov"
        $sshInvoker.isFileExists($rr) | Should -BeTrue
    }
    It "should scp 2 files to target folder." {
        $sshInvoker.scp("$kkvFileInSrcFolder $kkvFileInSrcFolder1", $remoteFolderNoEndSlash + '/', $true)
        $rr = "${remoteFolderNoEndSlash}/kkv.txt"
        $sshInvoker.isFileExists($rr) | Should -BeTrue

        $rr = "${remoteFolderNoEndSlash}/kkv1.txt"
        $rr =  $sshInvoker.isFileExists($rr) 
        $rr | Should -BeTrue
    }
}

