$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

. "${scriptDir}\common\SshInvoker.ps1"
. "${scriptDir}\common\clientside-util.ps1"


Describe "SshInvoker" {

    it "should parse config file." {
        $js = "[{a: 1}, {b: 2}]"
        $j = $js | ConvertFrom-Json
        $j -is [array] | Should -BeTrue
        $j | ForEach-Object {
            $_ | Out-Host
        }
        $j[0].a | Should -Be 1
        $j[1].b | Should -Be 2
    }

    it "should copy script to server." {
        $MyDir =  Join-Path -Path $scriptDir -ChildPath "mysql"
        $ConfigFile = $MyDir | Join-Path -ChildPath "demo-config.1.json"
        $sflf = $MyDir | Join-Path -ChildPath "serversidefilelist.txt"
        $configuration = Get-Configuration -ConfigFile $ConfigFile
        $configuration | Out-Host
        Copy-PsScriptToServer -configuration $configuration -ConfigFile $ConfigFile -ServerSideFileListFile $sflf
        [SshInvoker]$sshInvoker = Get-SshInvoker -configuration $configuration
        $sshInvoker.isFileExists($configuration.ServerSide.ScriptDir) | Should -BeTrue

        $invoker = Invoke-ServerRunningPs1 -configuration $configuration -ConfigFile $ConfigFile -action Echo a b c
        $invoker | Out-Host
    }
}