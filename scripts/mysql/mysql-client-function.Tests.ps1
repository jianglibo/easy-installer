$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$fixture = "${here}\fixtures\mysql-community.repo"

. ($here | Split-Path -Parent | Join-Path -ChildPath 'global-variables.ps1')
. $Global:SshInvoker
. $Global:CommonUtil
. $Global:ClientUtil


$ddd = @"
2018-03-03 21:21:00
2018-03-03 21:21:05
2018-03-03 21:21:10
2018-03-03 21:21:15
2018-03-03 21:21:20
2018-03-03 21:21:25

2018-03-03 21:11:20
2018-03-03 21:11:25
2018-03-03 21:11:30

2018-03-03 21:05:20
2018-03-03 21:05:25
2018-03-03 21:05:30

2018-03-03 20:11:20
2018-03-03 20:11:25
2018-03-03 20:11:30

2018-03-03 19:21:20
2018-03-03 19:21:25
2018-03-03 19:21:30

2018-03-02 20:11:20
2018-03-02 20:11:25
2018-03-02 20:11:30

2018-03-01 21:21:20
2018-03-01 21:21:25
2018-03-01 21:21:30

2018-02-02 20:11:20
2018-02-02 20:11:25
2018-02-02 20:11:30

2018-01-03 21:21:20
2018-01-03 21:21:25
2018-01-03 21:21:30

2017-02-02 20:11:20
2017-02-02 20:11:25
2017-02-02 20:11:30

2016-03-03 21:21:20
2016-03-03 21:21:25
2016-03-03 21:21:30
"@
# 2 2 0 2 2 2 3
# First group bye years, get group 2016, 2017, 2018, filter 2016 out, now get remain years 2017, 2018, keep last year 2018 untouched, keep last copy in 2017 group, delete others.
# 31
# Then group by month only in 2018, get 01, 02, 03, filter 01 out, keep 03 untouched, 02 keeep last one.
# 26
# Then group by days only in 03, get 01, 02,03 day group, filter 01 out, keep 03 untouched, 02 keep last one.

function get-demo {
    $kyou = Join-Path $TestDrive "kyou"
    $kyouSecond5 = Join-Path $TestDrive "kyouSecond5"
    $kyouMinute5 = Join-Path $TestDrive "kyouMinute5"
    $kyouHour2 = Join-Path $TestDrive "kyouHour2"
    $kino = Join-Path $TestDrive "kino"
    $ototoi = Join-Path $TestDrive "ototoi"
    $sennsyuu = Join-Path $TestDrive "sennsyuu"
    $sennsennsyuu = Join-Path $TestDrive "sennsennsyuu"
    $senngetu = Join-Path $TestDrive "senngetu"
    $sennsenngetu = Join-Path $TestDrive "sennsenngetu"
    $kyonen = Join-Path $TestDrive 'kyonen'
    $ototosi = Join-Path $TestDrive 'ototosi'

    $kyou = New-Item -Path $kyou -ItemType Directory
    $kyouSecond5 = New-Item -Path $kyouSecond5 -ItemType Directory
    $kyouMinute5 = New-Item -Path $kyouMinute5 -ItemType Directory
    $kyouHour2 = New-Item -Path $kyouHour2 -ItemType Directory 
    $kino = New-Item -Path $kino -ItemType Directory
    $ototoi = New-Item -Path $ototoi -ItemType Directory
    $sennsyuu = New-Item -Path $sennsyuu -ItemType Directory
    $sennsennsyuu = New-Item -Path $sennsennsyuu -ItemType Directory
    $senngetu = New-Item -Path $senngetu -ItemType Directory
    $sennsenngetu = New-Item -Path $sennsenngetu -ItemType Directory
    $kyonen = New-Item -Path $kyonen -ItemType Directory
    $ototosi = New-Item -Path $ototosi -ItemType Directory
    

    $now = $kyou.CreationTime
    $kyouSecond5.CreationTime = $now.AddSeconds(-5)
    $kyouMinute5.CreationTime = $now.AddMinutes(-5)
    $kyouHour2.CreationTime = $now.AddHours(-2)
    $kino.CreationTime = $now.AddDays(-1)
    $ototoi.CreationTime = $now.AddDays(-2)
    $sennsyuu.CreationTime = $now.AddDays(-7)
    $sennsennsyuu.CreationTime = $now.AddDays(-14)
    $senngetu.CreationTime = $now.AddMonths(-1)
    $sennsenngetu.CreationTime = $now.AddMonths(-2)
    $kyonen.CreationTime = $now.AddYears(-1)
    $ototosi.CreationTime = $now.AddYears(-2)
    $kyou,$kyouSecond5, $kyouMinute5, $kyouHour2, $kino, $ototoi, $senngetu, $sennsenngetu, $sennsennsyuu, $sennsyuu, $kyonen, $ototosi
}

Describe "local prune strategy" {
    it "should prune second" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 0 0 0 0 0 0'
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 2)
    }
}

Describe "local prune strategy1" {
    it "should prune second1" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 1 0 0 0 0 0' 
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 5)
    }
}

Describe "local prune strategy2" {
    it "should prune second2" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 2 0 0 0 0 0'
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 4)
    }
}
Describe "local prune strategy3" {
    it "should prune second3" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 2 0 2 0 0 0' 
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 6)
    }
}

Describe "local prune strategy4" {
    it "should prune second4" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 2 0 1 0 1 1'
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 10)
    }
}

function getfixture {
    $ddd -split "[\r\n]+" | Where-Object {$_} | ForEach-Object {@{CreationTime=(Get-Date $_)}} | Sort-Object -Property CreationTime
}

Describe "find backup files to delete" {
    it "should find yearly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 0 0 0 0 0 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 5 # all 3 of 2016, and 2 out of 3 in 2017.
    }
    it "should find monthly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 2 0 0 0 0 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 10 # 5 + 5
    }

    it "should find weekly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 0 2 0 0 0 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 10 # 5 + 5
    }

    it "should find dayly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 2 0 2 0 0 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 15 # 5 + 5 + 5
    }

    it "should find hourly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 2 0 2 2 0 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 20 # 5 + 5 + 5 + 5
    }

    it "should find minutely" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 2 0 2 2 2 0'
        "todelete $($toDelete.Count)" | Out-Host
        $toDelete.Count | Should -Be 25 # 5 + 5 + 5 + 5 + 5
    }

    it "should find secondly" {
        $v = getfixture
        "total $($v.Count)" | Out-Host
        $toDelete = Find-BackupFilesToDelete -FileOrFolders $v -Pattern '2 2 0 2 2 2 2'
        "todelete $($toDelete.Count)" | Out-Host
        # only the items in last minute participate find action. If group secondly, there will be one item per group.
        # But it does'nt matter, it still do right.
        # 2018-03-03 21:21:00
        # 2018-03-03 21:21:05
        # 2018-03-03 21:21:10
        # 2018-03-03 21:21:15
        # 2018-03-03 21:21:20
        # 2018-03-03 21:21:25
        $toDelete.Count | Should -Be 29 # 5 + 5 + 5 + 5 + 5 + 4
    }
}