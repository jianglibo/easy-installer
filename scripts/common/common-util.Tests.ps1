$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

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
}
