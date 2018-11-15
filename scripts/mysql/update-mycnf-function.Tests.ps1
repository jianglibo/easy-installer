$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

. "$here\mysql-server-function.ps1"

$fixture = "${here}\fixtures\my.cnf"

".\ssh-invoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

Describe "update my.cnf" {
    it "should update exists." {
        Update-Mycnf -Path $fixture -Key "a" -Value 1 | Where-Object {$_ -eq 'a=1'} | Measure-Object | Select-Object -ExpandProperty Count | should -Be 1
        $result = Update-Mycnf -Path $fixture -Key "a" -Value 1
        $result | Update-Mycnf -Key "a" | Where-Object {$_ -eq '#a=1'} | Measure-Object | Select-Object -ExpandProperty Count | should -Be 1

        $result = Update-Mycnf -Path $fixture -Key "a" -Value 1 | Update-Mycnf -Key "a" # result #a=1

        $result | update-mycnf -Key "a" -Value 1 | Where-Object {$_ -eq 'a=1'}  | Measure-Object | Select-Object -ExpandProperty Count | should -Be 1

        Update-Mycnf -Path $fixture -Key "a" -Value 1 -BlockName  'aaab' | Where-Object {$_ -eq '[aaab]'} | Should -BeTrue
        Update-Mycnf -Path $fixture -Key "a" -Value 1 -BlockName  'aaab' | Where-Object {$_ -eq 'a=1'} | Should -BeTrue

        Update-Mycnf -Path $fixture -Key "a" | Where-Object {$_ -eq 'a='} | Should -BeFalse
        Update-Mycnf -Path $fixture -Key "datadir" | Where-Object {$_ -eq '#datadir=/var/lib/mysql'} | Should -BeTrue
        Update-Mycnf -Path $fixture -Key "datadir" | Where-Object {$_ -eq 'datadir=/var/lib/mysql'} | Should -BeFalse

        Update-Mycnf -Path $fixture -Key "datadir" | Update-Mycnf -Key "server-id" -Value '2' | Out-Host
    }
}

