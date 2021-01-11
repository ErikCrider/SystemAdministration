<#
CCM Cache Cleanup
The CCM Cache folder is used by SCCM to store patches and software packages for install. Once these patches are installed these files are no longer needed and can be removed. 
The below script will get a current list of all windows servers out of active directory, and then attempt to reach out to them and delete these files. 
There are two phases. The first phase will return a list of servers that it is able to contact and is able to read the C:\Windows\CCMCache folder.  
This will provide a report that can be used to document what space is consumed on which server that is older than the specified time (default is 40 days).
The second phase is to delete the data that was reported above. 
This section is intentionally commented out so that this phase is not automatically run, and gives you a chance to run it after reviewing the initial output if desired
This script looks for all servers in Active Directory with the Active Directory attribute OperatingSystem like "*Windows Server*"
It then attempts to ping them and if pingable, verifies the path is accessible
If files are found older than X days (configurable in script below) it will output these to a file.
You can then run the last lines of the script (currently commented out) to delete these files.
This must be run with an account that has access to the servers
Open Powershell as your elevated credentials and then opened with RunAs using the command below
Start-process Powershell.exe -verb RunAs
Author: Erik Crider
Date:   10/08/2020

Updates
01/08/21	Updated column names so directory size is number.
		Added text at bottom of script for next steps
#>

## Set how many days back to delete from
$DaysOld = "-40"

##  Gather all servers, output to a file
$date = (get-date -uformat "%m-%d-%Y-%R" | ForEach-Object { $_ -replace ":", "." }) 
$Servers = "c:\temp\Servers" + $Date+'.txt' 
Write-Host "Getting list of servers from AD"
Get-ADComputer -Filter {( OperatingSystem -Like '*Windows Server*') } | sort name | select -expandproperty name | Out-File $Servers


##Variables to be used to hold data in the script below
$dataColl = @()
$GoodServerList = @()
$BadServerList = @()
$ServerList = Get-content $servers
$GoodPathList = @()
$BadPathList = @()

##  Attempt to ping each server in the list, separate into two variables with only the pingable servers going forward
Write-Host "Attempting to ping servers"
foreach ($serverName in $Serverlist){
If (test-connection -ComputerName $servername -Quiet -Count 1){
$GoodServerList += $Servername
} else {
$BadServerList +=$servername}
}

##  From the servers with the CCMCache folder, check for files older than X days as defined in $DaysOld, report back their size
Foreach ($server in $GoodServerList){
if (test-path "\\$server\c$\windows\ccmcache") {
$GoodPathList += $Server
$path = "\\$Server\c$\windows\ccmcache"
$dirSize = Get-ChildItem $path -recurse -force | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays($DaysOld))} | select Length |Measure-Object -Sum length
If ($dirsize -ne $Null){
$dirSize.sum = $dirSize.sum/1MB
$finalResult = "{0:N2}" -f $dirSize.sum
} else {
write-host "No files older than $daysold days old on $Server"
}
$dataObject = New-Object PSObject
Add-Member -inputObject $dataObject -memberType NoteProperty -name "ServerName" -value $server
Add-Member -inputObject $dataObject -memberType NoteProperty -name "Dir_Size_MB" -value $finalResult
$dataColl += $dataObject 
[int]$DevcurrentItem = [array]::indexof($GoodServerList,$Server)
Write-Progress -Activity "Getting CCMCache Folders" -Status "Server $($DevcurrentItem) of $($GoodServerList.Count - 1) - $([math]::round((($DevcurrentItem + 1)/$GoodServerList.Count),2) * 100)%  - Currently checking - $($Server)" -PercentComplete $([float](($DevcurrentItem + 1)/$GoodServerList.Count) * 100)
$dataObject
} else {
$BadPathList += $Server
Write-Host "Unable to access path on $Server"}
}


$dataColl | Out-GridView -Title "Remote Directory Scan Results" # On screen review of all servers and file sizes over X days as defined in $DaysOld
$Outputfile = "c:\temp\CCMCache-" + $Date + '.csv' # Needed for file output below
$dataColl | Export-Csv -noTypeInformation -path $OutputFile # Outputs results to a file for documentation purposes
$BadServerList | Out-Gridview -title "Unpingable Servers" # To review servers that are not pingable
$GoodPathList | Out-GridView -Title "GoodPathList" # To review servers that have CCMCache Folder
$BadPathList | Out-GridView -Title "BadPathList" # To review servers that do not have the CCMCache folder.



## To run the cleanup after the fact, import the CSV file by updating the filename below and copy pasting into PowerShell
<#
Foreach ($Computer in import-csv c:\temp\CCMCache-12-22-2020-07.34.csv){
$ServerName = $Computer.Servername
Get-ChildItem -Path "\\$ServerName\C$\windows\ccmcache" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-40))} | Remove-Item -recurse
}
#> 

write-host "List of servers with files to be deleted in $Outputfile"
write-host "Use in next step with the following example code"
write-host "Foreach (`$Computer in import-csv $Outputfile){"
write-host '$ServerName = $Computer.Servername'
write-host 'Get-ChildItem -Path "\\$ServerName\C$\windows\ccmcache" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-40))} | Remove-Item -recurse}'

