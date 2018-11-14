$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common-util.ps1"

$scriptDir = $here | Split-Path -Parent

. "$here\common-for-t.ps1"

$tcfg = Get-Content -Path ($here | Join-Path -ChildPath "common-util.t.json") | ConvertFrom-Json

Describe "should backup" {
    $plainfile = Join-Path $TestDrive "plain.txt"
    1..5 -join ' ' | Out-File $plainfile
    it "should do right." {
        $m = Get-MaxBackupNumber -Path $plainfile
        $m | Should -Be 0

        $m = Backup-LocalDirectory -Path $plainfile

        $m | Should -Be "${plainfile}.1"

        $m = Get-MaxBackupNumber -Path $plainfile
        $m | Should -Be 1

        $m = Get-NextBackup -Path $plainfile
        $m | Should -Be "${plainfile}.2"

        $m = Backup-LocalDirectory -Path "${plainfile}.1" -keepOrigin
        $m | Should -Be "${plainfile}.2"
        $m = Backup-LocalDirectory -Path "${plainfile}.1"
        $m | Should -Be "${plainfile}.3"
    }
}

