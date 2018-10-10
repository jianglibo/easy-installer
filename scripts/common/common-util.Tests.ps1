$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$scriptDir = $here | Split-Path -Parent

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
