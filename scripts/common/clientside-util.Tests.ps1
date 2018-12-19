$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

. ($here | Split-Path -Parent | Join-Path -ChildPath 'global-variables.ps1')
. $Global:SshInvoker
. $Global:CommonUtil
. $Global:ClientUtil
. "${scriptDir}\common\common-for-t.ps1"


$cfgfile = $scriptDir | Join-Path -ChildPath "mysql" |Join-Path -ChildPath "demo-config.1.json"

function Get-FixtureFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    $here | Join-Path -ChildPath "fixtures" | Join-Path -ChildPath $FileName
}

Describe "configuration" {
    it "should get configuration." {
        Get-Configuration -ConfigFile $cfgfile -ServerSide
        $Global:configuration.openssl | Should -Be "openssl"

        Get-Configuration -ConfigFile $cfgfile 
        $Global:configuration.openssl | Should -Be "openssl" # still to be openssl. Because we had added ClientOpenssl property.

        $Global:configuration.DownloadPackages()

        Send-SoftwarePackages
    }
}

Describe "lines" {
    it "should lines." {
        [array]$lines = Get-Content -Path (Get-FixtureFile -FileName 'lines7.txt')
        $lines.Count | Should -Be 7
        [array]$lines = Get-Content -Path (Get-FixtureFile -FileName 'lines7.txt') | Where-Object {$_}
        $lines.Count | Should -Be 4
    }
}

Describe "copy scripts to server." {

    it "should parse config file." {
        $js = "[{a: 1}, {b: 2}]"
        $j = $js | ConvertFrom-Json
        $j -is [array] | Should -BeTrue
        # $j | ForEach-Object {
        #     $_ | Out-Host
        # }
        $j[0].a | Should -Be 1
        $j[1].b | Should -Be 2
    }

    it "should copy script to server." {
        $PSDefaultParameterValues['*:Verbose'] = $true
        $mysql = Join-Path -Path $scriptDir -ChildPath "mysql"
        $ht = Copy-TestPsScriptToServer -HerePath $mysql
        # $ht | Out-Host
        [SshInvoker]$sshInvoker = Get-SshInvoker -configuration $ht.configuration
        $sshInvoker.isFileExists($ht.configuration.ServerSide.ScriptDir) | Should -BeTrue
        $result = Invoke-ServerRunningPs1 -action Echo a b c | Receive-LinesFromServer
        $result | Should -Be 'a b c'
    }
}