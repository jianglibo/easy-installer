$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

. "${scriptDir}\common\ssh-invoker.ps1"
. "${scriptDir}\common\clientside-util.ps1"
. "${scriptDir}\common\common-for-t.ps1"

$cfgfile = $scriptDir | Join-Path -ChildPath "mysql" |Join-Path -ChildPath "demo-config.1.json"

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

Describe "SshInvoker" {

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
        $PSDefaultParameterValues['*:Verbose'] = $false
        $mysql = Join-Path -Path $scriptDir -ChildPath "mysql"
        $ht = Copy-TestPsScriptToServer -HerePath $mysql
        # $ht | Out-Host
        [SshInvoker]$sshInvoker = Get-SshInvoker -configuration $ht.configuration
        $sshInvoker.isFileExists($ht.configuration.ServerSide.ScriptDir) | Should -BeTrue
        $result = Invoke-ServerRunningPs1 -ConfigFile $ht.ConfigFile -action Echo a b c
        $result | Should -Be 'a b c'
    }
}