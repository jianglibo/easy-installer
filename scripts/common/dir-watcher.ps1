param (
    [parameter(Mandatory = $true)]
    [string]$Folder,
    [parameter(Mandatory = $false)]
    [string]$Filter="*.*",
    [switch]$Recurse
)
 
$fsw = New-Object IO.FileSystemWatcher $Folder, $Filter -Property @{IncludeSubdirectories = $Recurse; NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'} 

# return a job object.
Register-ObjectEvent -InputObject $fsw  -EventName Created -SourceIdentifier FileCreated -Action { 
    $name = $Event.SourceEventArgs.Name 
    $changeType = $Event.SourceEventArgs.ChangeType 
    $timeStamp = $Event.TimeGenerated 
    Write-Host "The file '$name' was $changeType at $timeStamp" -fore green 
    # Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
} 
 
Register-ObjectEvent -InputObject $fsw -EventName Deleted -SourceIdentifier FileDeleted -Action { 
    $name = $Event.SourceEventArgs.Name 
    $changeType = $Event.SourceEventArgs.ChangeType 
    $timeStamp = $Event.TimeGenerated 
    Write-Host "The file '$name' was $changeType at $timeStamp" -fore red 
    # Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
} 
 
Register-ObjectEvent -InputObject $fsw -EventName Changed -SourceIdentifier FileChanged -Action { 
    $name = $Event.SourceEventArgs.Name 
    $changeType = $Event.SourceEventArgs.ChangeType 
    $timeStamp = $Event.TimeGenerated 
    Write-Host "The file '$name' was $changeType at $timeStamp" -fore white 
    # Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
} 
 
# To stop the monitoring, run the following commands: 
# Unregister-Event FileDeleted 
# Unregister-Event FileCreated 
# Unregister-Event FileChanged