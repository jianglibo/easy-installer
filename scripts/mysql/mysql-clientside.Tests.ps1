$myself = $MyInvocation.MyCommand.Path
$here = $myself | Split-Path -Parent
$ScriptDir = $here | Split-Path -Parent

$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$fixture = "${here}\fixtures\mysql-community.repo"

".\ssh-invoker.ps1", ".\common-util.ps1", ".\clientside-util.ps1", "common-for-t.ps1" | ForEach-Object {
    . "${ScriptDir}\common\$_"
}

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

    $kyou,$kyouSecond5, $kyouMinute5, $kyouHour2, $kino, $ototoi, $senngetu, $sennsenngetu, $sennsennsyuu, $sennsyuu
}

Describe "local prune strategy" {
    it "should prune second" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 0 0 0 0 0 0'
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 1)
    }
}

Describe "local prune strategy1" {
    it "should prune second1" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 1 0 0 0 0 0' # keep one minutely, so kynoMinute5 will be deleted.
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 2)
    }
}

Describe "local prune strategy2" {
    it "should prune second2" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 2 0 0 0 0 0' # keep two minutely, so kynoMinute5 will be keeped.
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 1)
    }
}
Describe "local prune strategy3" {
    it "should prune second3" {
        [array]$all = get-demo
        Resize-BackupFiles -BasePath $all[0] -Pattern '1 2 2 0 0 0 0' # keep two minutely, so kynoMinute5 will be keeped.
        [array]$remains = $all | Where-Object {Test-Path -Path $_}
        $remains.Count | Should -Be ($all.Count - 2)
    }
}