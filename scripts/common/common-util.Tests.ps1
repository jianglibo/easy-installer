$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

. "$here\common-for-t.ps1"

$tcfg = Get-Content -Path ($here | Join-Path -ChildPath "common-util.t.json") | ConvertFrom-Json


Describe "copy-exclude" {
        $sourcefolder = Join-Path $TestDrive "source"
        $d = New-Item -ItemType Directory -Path $sourcefolder

        $a = New-Item -ItemType Directory -Path ($sourcefolder | Join-Path -ChildPath 'a')
        $b = New-Item -ItemType Directory -Path ($sourcefolder | Join-Path -ChildPath 'b')

        $af = New-Item -Path ($a | Join-Path -ChildPath '1.txt');
        $bf = New-Item -Path ($b | Join-Path -ChildPath '2.txt');

        $dstfolder = Join-Path $TestDrive "dst"
        it "should exclude " {
            Copy-Item -Path $sourcefolder -Recurse -Destination $dstfolder -Exclude 'b'

            $da = $dstfolder | Join-Path -ChildPath 'a' | Join-Path -ChildPath '1.txt'
            $db = $dstfolder | Join-Path -ChildPath 'b' | Join-Path -ChildPath '2.txt'

            Test-Path $da | Should -BeTrue
            Test-Path $db | Should -BeFalse
        }
}

Describe "common-util" {
    It "should split url" {
        Split-Url -Url "abc/" | Should -Be ''
        Split-Url -Url "a/abc/" | Should -Be ''
        Split-Url -Url "a/abc/" -ItemType Container | Should -Be "a/abc/"
        Split-Url -Url "http://www.abc.com" -ItemType Container | Should -Be "http://www.abc.com"
        Split-Url -Url "http://www.abc.com" -ItemType Leaf | Should -Be ''
        Split-Url -Url "https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-community-common-5.7.23-1.el7.x86_64.rpm" | Should -Be 'mysql-community-common-5.7.23-1.el7.x86_64.rpm'
        Split-Url -Url "https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-community-common-5.7.23-1.el7.x86_64.rpm" -ItemType Container | Should -Be 'https://cdn.mysql.com//Downloads/MySQL-5.7/'
    }

    it "here should be a string" {
        $here | Should -BeOfType [string]
        $here | Out-Host
    }

    it "should split-univeral " {
        $MyDir = Join-Path -Path $scriptDir -ChildPath "mysql"
        $ConfigFile = $MyDir | Join-Path -ChildPath "demo-config.1.json"
        $sflf = $MyDir | Join-Path -ChildPath "serversidefilelist.txt"

        Get-Content -Path $sflf | ForEach-Object {Split-UniversalPath -Path $_} | ForEach-Object {
            ([string]$_).IndexOf('\') | Should -Be -1
            ([string]$_).IndexOf('/') | Should -Be -1
        }

        Join-UniversalPath -Path "/tmp/sciprt" -ChildPath "*.ps1" | Should -Be "/tmp/sciprt/*.ps1"
        "/tmp/sciprt" | Join-UniversalPath -ChildPath "*.ps1" | Should -Be "/tmp/sciprt/*.ps1"

        "/tmp/sciprt" | Split-UniversalPath -Leaf | Should -Be 'sciprt'
        "https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-community-common-5.7.23-1.el7.x86_64.rpm" | Split-UniversalPath -Leaf | Should -Be "mysql-community-common-5.7.23-1.el7.x86_64.rpm"
    }

    it "should handle remain parameters" {
        function fr-rm {
            param(
                [Parameter(ValueFromRemainingArguments = $true)]
                $pp
            )
            Get-RemainParameterHashtable -hints $pp
        }

        $ht = Get-RemainParameterHashtable -hints "-a", 1, 3, 34
        $ht.a |Should -Be 1
        ($ht._orphans) | Should -Be 3, 34

        $ht = fr-rm a b -c d e
        $ht.c | Should -Be 'd'

        $ht = "-a", 1, 3, 34 | Get-RemainParameterHashtable
        $ht.a |Should -Be 1
        ($ht._orphans) | Should -Be 3, 34
    }
}


function split($inFile, $outPrefix, [Int32] $bufSize) {

    $stream = [System.IO.File]::OpenRead($inFile)
    $chunkNum = 1
    $barr = New-Object byte[] $bufSize
  
    while ( $bytesRead = $stream.Read($barr, 0, $bufsize)) {
        $outFile = "$outPrefix$chunkNum"
        $ostream = [System.IO.File]::OpenWrite($outFile)
        $ostream.Write($barr, 0, $bytesRead);
        $ostream.close();
        echo "wrote $outFile"
        $chunkNum += 1
    }

    $stream
}

#   https://docs.microsoft.com/en-us/dotnet/api/system.io.filestream?view=netframework-4.7.2
  
Describe "open io" {
    $outFile = Join-Path $TestDrive "plain.bin"
    $outFile1 = Join-Path $TestDrive "plain.bin1"
    it "should write int." {
        # $utf8 = [System.Text.Encoding]::UTF8
        $ostream = [System.IO.File]::OpenWrite($outFile)
        $bytes = [bitconverter]::GetBytes([int32]5566)
        $ostream.write($bytes, 0, $bytes.Length)
        $ostream.close()
        $ostream.dispose()

        # [Int32]::MaxValue
        # 2147483647

        $instream = [System.IO.File]::OpenRead($outFile)
        $barr = New-Object byte[] 100
        $c = $instream.Read($barr, 0, 100)
        $c | Should -Be $bytes.Length
        $instream.close()
        $instream.dispose()

        $ib = $barr[0..($c - 1)]
        # $ib.Length | Should -Be $c
        [bitconverter]::ToInt32($ib, 0) | Should -Be 5566
    }

    it "should join one small files" {
        "abc" | Out-File -FilePath $outFile1 -Encoding ascii -NoNewline # for test only
        $hash1 = Get-FileHash -Path $outFile1
        $combined = Join-Files -FileNamePairs $outFile1
        # 4 + 10(filename) + 4 + 3(file content)
        (Get-Item -Path $combined).Length | Should -Be 21

        # plain.bin1

        $dst = Split-Files -CombinedFile $combined

        $f1 = Join-Path -Path $dst -ChildPath "plain.bin1"
        $hash2 = Get-FileHash -Path $f1
        $hash1.Hash | Should -Be $hash2.Hash
        Test-Path -Path $f1 -PathType Leaf | Should -BeTrue
        Get-Content -Path $f1 | Should -Be "abc"
    }

    it "should join renamed 1 small file" {
        "abc" | Out-File -FilePath $outFile1 -Encoding ascii -NoNewline # for test only
        $hash1 = Get-FileHash -Path $outFile1
        $combined = Join-Files -FileNamePairs @{file = $outFile1; name = "hello.txt1"}
        # 4 + 10(filename) + 4 + 3(file content)
        (Get-Item -Path $combined).Length | Should -Be 21

        # plain.bin1
        $dst = Split-Files -CombinedFile $combined
        $f1 = Join-Path -Path $dst -ChildPath "hello.txt1"
        $hash2 = Get-FileHash -Path $f1
        $hash1.Hash | Should -Be $hash2.Hash
        Test-Path -Path $f1 -PathType Leaf | Should -BeTrue
        Get-Content -Path $f1 | Should -Be "abc"
    }

    it "should join renamed 1 large file" {
        1..50000 -join ' ' | Out-File -FilePath $outFile1 -Encoding ascii -NoNewline # for test only
        $hash1 = Get-FileHash -Path $outFile1
        $combined = Join-Files -FileNamePairs @{file = $outFile1; name = "hello.txt1"}

        # plain.bin1
        $dst = Split-Files -CombinedFile $combined
        $f1 = Join-Path -Path $dst -ChildPath "hello.txt1"
        $hash2 = Get-FileHash -Path $f1
        $hash1.Hash | Should -Be $hash2.Hash
    }

    it "should join renamed 2 small file" {
        "akl1234" | Out-File -FilePath $outFile1 -Encoding ascii -NoNewline # for test only
        "llluukv" | Out-File -FilePath $outFile -Encoding ascii -NoNewline # for test only
        $hash1 = Get-FileHash -Path $outFile1
        $combined = Join-Files -FileNamePairs @{file = $outFile1; name = "hello.txt1"}, $outFile

        # plain.bin1
        $dst = Split-Files -CombinedFile $combined
        $f1 = Join-Path -Path $dst -ChildPath "hello.txt1"
        $hash2 = Get-FileHash -Path $f1
        $hash1.Hash | Should -Be $hash2.Hash

        $f2 = Join-Path -Path $dst -ChildPath "plain.bin"

        (Get-FileHash -Path $outFile).Hash | Should -Be (Get-FileHash -Path $f2).Hash

    }

    it "should join renamed 2 large file" {
        1..50000 -join ' ' | Out-File -FilePath $outFile1 -Encoding ascii -NoNewline # for test only
        1..23457 -join ' ' | Out-File -FilePath $outFile -Encoding ascii -NoNewline # for test only
        $hash1 = Get-FileHash -Path $outFile1
        $combined = Join-Files -FileNamePairs @{file = $outFile1; name = "hello.txt1"}, $outFile

        # plain.bin1
        $dst = Split-Files -CombinedFile $combined
        $f1 = Join-Path -Path $dst -ChildPath "hello.txt1"
        $hash2 = Get-FileHash -Path $f1
        $hash1.Hash | Should -Be $hash2.Hash

        $f2 = Join-Path -Path $dst -ChildPath "plain.bin"

        (Get-FileHash -Path $outFile).Hash | Should -Be (Get-FileHash -Path $f2).Hash
    }

}



Describe "very big file" {
    it "should join real file" {
        $f = "C:\Users\Administrator\AppData\Local\Temp\tmp5082.tmp"

        Split-Files -CombinedFile $f -dstFolder "f:\kkk" -bufsize 2048
        
    }
}

Describe "openssl" {
    $plainfile = Join-Path $TestDrive "plain.txt"
    1..5000 -join ' ' | Out-File $plainfile
    it "should encrypt." {
        Get-DemoConfiguration -HerePath (Join-Path -Path $scriptDir -ChildPath "mysql") -ServerSide
        $encrypted = Protect-ByOpenSSL -ServerPublicKeyFile $tcfg.ServerPublicKeyFile -PlainFile $plainfile
        Test-Path -Path $encrypted -PathType Leaf | Should -BeTrue

        Get-DemoConfiguration -HerePath (Join-Path -Path $scriptDir -ChildPath "mysql")

        $decrypted = UnProtect-ByOpenSSL -ServerPrivateKeyFile $tcfg.ServerPrivateKeyFile -CombinedEncriptedFile $encrypted -openssl $Global:configuration.ClientOpenssl
        $LASTEXITCODE | Should -Be 0
        Get-Content -Path $decrypted | Should -Be (1..5000 -join ' ')
    }
}

Describe "base64" {
    $plainfile = Join-Path $TestDrive "plain.txt"
    $plainfile1 = Join-Path $TestDrive "plain.txt1"
    it "should convert." {
        "akkddls ss " | Out-File -FilePath $plainfile
        $b64 = Get-Base64FromFile -File $plainfile
        $f = Get-FileFromBase64 -Base64 $b64 -OutFile $plainfile1

        (Get-FileHash $plainfile).Hash | Should -Be (Get-FileHash $plainfile1).Hash
    }
}

Describe "zip function" {
    it "should zip." {
        $a = @(1,2,3)
        $b = @(4,5,6)
        $tp = Zip-List -Aarray $a -Barray $b | Select-Object -First 1

        $tp.item1 | Should -Be 1
        $tp.item2 | Should -Be 4
    }
}

Describe "hash string value." {
    it "should hash." {
        $h = Get-StringHash -String 'hello hash'
        $h1 = Get-StringHash -String 'hello hash'

        $h | Should -Be $h1
    }
}

Describe "protect password" {
    it "should convert." {
        $ss = ConvertTo-SecureString -String "123456" -AsPlainText -Force  # | ConvertFrom-SecureString
        Get-DemoConfiguration -HerePath (Join-Path -Path $scriptDir -ChildPath "mysql")
        $base64 = Protect-PasswordByOpenSSLPublicKey -ServerPublicKeyFile $tcfg.ServerPublicKeyFile -ss $ss
        $plainPwd = UnProtect-PasswordByOpenSSLPublicKey  -base64 $base64 -ServerPrivateKeyFile $tcfg.ServerPrivateKeyFile -OpenSSL $Global:configuration.ClientOpenssl
        $plainPwd | should -Be "123456"
    }
}

Describe "hash table" {
    it "should like dict." {
        $ht = @{}
        $ms = '.*>$'
        if ($ht.ContainsKey($ms)) {
            $ht[$ms] += 1
        }
        else {
            $ht[$ms] = 0
        }
        $ht[$ms] | Should -Be 0
    }
}

Describe "data between client and server." {
    it "should parse result" {
        "abc", "for-easyinstaller-client-use-start", "123", "for-easyinstaller-client-use-end" | Receive-LinesFromServer | Should -Be "123"

        Send-LinesToClient -InputObject "123" | Receive-LinesFromServer | Should -Be "123"
        "123" | Send-LinesToClient | Receive-LinesFromServer | Should -Be "123"

        
        ("1","2" | Send-LinesToClient),("3", "4" | Send-LinesToClient) | ForEach-Object {$_} | Receive-LinesFromServer -section 0 | Should -Be 1,2
        ("1","2" | Send-LinesToClient),("3", "4" | Send-LinesToClient) | ForEach-Object {$_} | Receive-LinesFromServer -section 1 | Should -Be 3,4
    }
}

# Describe "process control" {
#     it "should start cmd" {
#         # Start-PasswordPromptCommand -Command "mysql"  -Arguments "-uroot -p" -mysqlpwd "123456"
#         # Start-PasswordPromptCommand -Command "cmd"  -Arguments "/K dir" -mysqlpwd "123456"
#         # Start-PasswordPromptCommandSync -Command "powershell"  -Arguments "-Command cmd /K dir" -mysqlpwd "123456"
#         Start-PasswordPromptCommandSync -Command "cmd"  -Arguments "/K dir" -mysqlpwd "123456"

#         # Invoke-Executable -sExeFile "cmd" -cArgs "/C", "dir"
#     }
# }


Describe "String convert" {
    it "should convert string" {
        # 230 136 145 230 152 175 232 176 129 hxd
        # 230 136 145 230 152 175 232 176 129 utf8
        # 230 136 145 230 152 175 232， utf8 file read as cp936，then read bytes as cp936
        # 233 142 180 230 136 158 230 167 184 231 146 139， utf8 file read as cp936，then read bytes as utf8


        $utf8 = [System.Text.Encoding]::UTF8
        $df = [System.Text.Encoding]::Default

        # $dd = [System.Text.Encoding]::GetEncoding(936)
        # 
        $str = Get-Content -Path "utf8.txt"
        $bytes = $utf8.GetBytes($str)
        "$bytes" | Out-Host
        $bytes = $df.GetBytes($str)
        "$bytes" | Out-Host
        $str | Out-Host # this is a wrong encoded string. It is utf8, but wrongly read as cp936
        $bytes = $df.GetBytes($str)

        # $utfstr = $df.GetString($bytes)
        # $c = [System.Text.Encoding]::Convert($df, $utf8, $bytes)
        $utf8str = $utf8.GetString($bytes)
        $utf8str | Out-Host
        "我是谁" | Out-Host
    }
}

Describe "relativelize path." {
    it "should work." {
        Resolve-RelativePathToAnotherPath -ParentPath '/a/' -FullPath '/a/b/c' | Should -Be 'b/c'
        Resolve-RelativePathToAnotherPath -ParentPath 'c:/a/' -FullPath 'c:/a/b/c' | Should -Be 'b/c'
        Resolve-RelativePathToAnotherPath -ParentPath 'c:\a\' -FullPath 'c:/a/b/c' | Should -Be 'b\c'
        Resolve-RelativePathToAnotherPath -ParentPath 'c:\a\' -FullPath 'c:/a/b/c' -Separator '/' | Should -Be 'b/c'
        {Resolve-RelativePathToAnotherPath -ParentPath 'c:\a\' -FullPath 'a/b/c'}| Should -Throw 'Path is not absolute:'
    }
}

Describe "Format-List out" {
    it "should parse out" {
        $f = "$here\listout.txt"
        [array]$r = Get-Content -Path $f | ConvertFrom-ListFormatOutput
        
        $r.Count | Should -Be 2
    }
}
# Describe "process control executable" {
#     it "should start cmd" {
#         Invoke-Executable -sExeFile "cmd" -cArgs "/C", "dir"
#     }
# }
# $procTools = @"

# using System;
# using System.Diagnostics;

# namespace Proc.Tools
# {
#   public static class exec
#   {
#     public static int runCommand(string executable, string args = "", string cwd = "", string verb = "runas") {

#       //* Create your Process
#       Process process = new Process();
#       process.StartInfo.FileName = executable;
#       process.StartInfo.UseShellExecute = false;
#       process.StartInfo.CreateNoWindow = true;
#       process.StartInfo.RedirectStandardOutput = true;
#       process.StartInfo.RedirectStandardError = true;
#     //*  process.StartInfo.RedirectStandardInput = true;

#       //* Optional process configuration
#       if (!String.IsNullOrEmpty(args)) { process.StartInfo.Arguments = args; }
#       if (!String.IsNullOrEmpty(cwd)) { process.StartInfo.WorkingDirectory = cwd; }
#       if (!String.IsNullOrEmpty(verb)) { process.StartInfo.Verb = verb; }

#       //* Set your output and error (asynchronous) handlers
#       process.OutputDataReceived += new DataReceivedEventHandler(OutputHandler);
#       process.ErrorDataReceived += new DataReceivedEventHandler(OutputHandler);

#       //* Start process and handlers
#       process.Start();
#       process.BeginOutputReadLine();
#       process.BeginErrorReadLine();
#       process.WaitForExit();

#       //* Return the commands exit code
#       return process.ExitCode;
#     }
#     public static void OutputHandler(object sendingProcess, DataReceivedEventArgs outLine) {
#       //* Do your stuff with the output (write to console/log/StringBuilder)
#       Console.WriteLine(outLine.Data);
#     }
#   }
# }
# "@

# Describe "csharp" {
#     it "should start cmd" {
#         Add-Type -TypeDefinition $procTools -Language CSharp
#         $PSDefaultParameterValues['*:Encoding'] = 'utf8'
#         $puppetApplyRc = [Proc.Tools.exec]::runCommand("cmd", "/K dir");

#         if ( $puppetApplyRc -eq 0 ) {
#             Write-Host "The run succeeded with no changes or failures; the system was already in the desired state."
#         }
#         elseif ( $puppetApplyRc -eq 1 ) {
#             throw "The run failed; halt"
#         }
#         elseif ( $puppetApplyRc -eq 2) {
#             Write-Host "The run succeeded, and some resources were changed."
#         }
#         elseif ( $puppetApplyRc -eq 4 ) {
#             Write-Warning "WARNING: The run succeeded, and some resources failed."
#         }
#         elseif ( $puppetApplyRc -eq 6 ) {
#             Write-Warning "WARNING: The run succeeded, and included both changes and failures."
#         }
#         else {
#             throw "Un-recognised return code RC: $puppetApplyRc"
#         }
#     }
# }

