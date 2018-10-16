﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

$tcfg = Get-Content -Path ($here | Join-Path -ChildPath "common-util.t.json") | ConvertFrom-Json

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
    }
}

Describe "openssl" {
    $plainfile = Join-Path $TestDrive "plain.txt"
    $plainfile1 = Join-Path $TestDrive "plain1.txt"
    "abc" | Out-File $plainfile
    it "should encrypt." {
        $tcfg | Out-Host
        $encrypted = Protect-ByOpenSSL -PublicKeyFile $tcfg.PublicKeyFile -PlainFile $plainfile
        Test-Path -Path $encrypted -PathType Leaf | Should -BeTrue
        $decrypted = UnProtect-ByOpenSSL -PrivateKeyFile $tcfg.PrivateKeyFile -encryptedFile $encrypted -decryptedFile $plainfile1
        $LASTEXITCODE | Should -Be 0
        Get-Content -Path $plainfile1 | Should -Be "abc"
    }
}

Describe "hash table" {
    it "should like dict." {
        $ht = @{}
        $ms = '.*>$'
        if ($ht.ContainsKey($ms)) {
            $ht[$ms] += 1
        } else {
            $ht[$ms] = 0
        }
        $ht[$ms] | Should -Be 0
    }
}

Describe "process control" {
    it "should start cmd" {
        # Start-PasswordPromptCommand -Command "mysql"  -Arguments "-uroot -p" -mysqlpwd "123456"
        # Start-PasswordPromptCommand -Command "cmd"  -Arguments "/K dir" -mysqlpwd "123456"
        # Start-PasswordPromptCommandSync -Command "powershell"  -Arguments "-Command cmd /K dir" -mysqlpwd "123456"
        Start-PasswordPromptCommandSync -Command "cmd"  -Arguments "/K dir" -mysqlpwd "123456"

        # Invoke-Executable -sExeFile "cmd" -cArgs "/C", "dir"
    }
}


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

Describe "process control executable" {
    it "should start cmd" {
        Invoke-Executable -sExeFile "cmd" -cArgs "/C", "dir"
    }
}
$procTools = @"

using System;
using System.Diagnostics;

namespace Proc.Tools
{
  public static class exec
  {
    public static int runCommand(string executable, string args = "", string cwd = "", string verb = "runas") {

      //* Create your Process
      Process process = new Process();
      process.StartInfo.FileName = executable;
      process.StartInfo.UseShellExecute = false;
      process.StartInfo.CreateNoWindow = true;
      process.StartInfo.RedirectStandardOutput = true;
      process.StartInfo.RedirectStandardError = true;
    //*  process.StartInfo.RedirectStandardInput = true;

      //* Optional process configuration
      if (!String.IsNullOrEmpty(args)) { process.StartInfo.Arguments = args; }
      if (!String.IsNullOrEmpty(cwd)) { process.StartInfo.WorkingDirectory = cwd; }
      if (!String.IsNullOrEmpty(verb)) { process.StartInfo.Verb = verb; }

      //* Set your output and error (asynchronous) handlers
      process.OutputDataReceived += new DataReceivedEventHandler(OutputHandler);
      process.ErrorDataReceived += new DataReceivedEventHandler(OutputHandler);

      //* Start process and handlers
      process.Start();
      process.BeginOutputReadLine();
      process.BeginErrorReadLine();
      process.WaitForExit();

      //* Return the commands exit code
      return process.ExitCode;
    }
    public static void OutputHandler(object sendingProcess, DataReceivedEventArgs outLine) {
      //* Do your stuff with the output (write to console/log/StringBuilder)
      Console.WriteLine(outLine.Data);
    }
  }
}
"@

Describe "csharp" {
    it "should start cmd" {
        Add-Type -TypeDefinition $procTools -Language CSharp
        $PSDefaultParameterValues['*:Encoding'] = 'utf8'
        $puppetApplyRc = [Proc.Tools.exec]::runCommand("cmd", "/K dir");

        if ( $puppetApplyRc -eq 0 ) {
            Write-Host "The run succeeded with no changes or failures; the system was already in the desired state."
        }
        elseif ( $puppetApplyRc -eq 1 ) {
            throw "The run failed; halt"
        }
        elseif ( $puppetApplyRc -eq 2) {
            Write-Host "The run succeeded, and some resources were changed."
        }
        elseif ( $puppetApplyRc -eq 4 ) {
            Write-Warning "WARNING: The run succeeded, and some resources failed."
        }
        elseif ( $puppetApplyRc -eq 6 ) {
            Write-Warning "WARNING: The run succeeded, and included both changes and failures."
        }
        else {
            throw "Un-recognised return code RC: $puppetApplyRc"
        }
    }
}

