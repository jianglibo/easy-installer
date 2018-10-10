$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. "$here\$sut"

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
}