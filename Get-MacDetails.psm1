<#
.SYNOPSIS
    Gathers details of virtual machines from a list of MAC address.

.DESCRIPTION
    By searching through all specified vCenter servers for all MAC address associated with Guest VMs, it returns details about the VM, including Name, IPAddresses, VMHost, vCenter.
    Can also gather details from a txt file list of MACs or by entering a string of MACs on the command line.  The output is exported to a designated CSV file and emailed to the
    hard-coded address.

.PARAMETER Vcenter
    This specifies the vCenter server(s) that the script will run against, comma separated.  For Example, "vc01,vc02".

.Parameter AutoMac
    This determines if a manual list of selected MACs to scan for will be used or if all MACs on given vCenter server(s) will be used.  Default is $false, set by -AutoMac:$true.

.Parameter MacFile
    This specifies the path to a manual list of MAC Address for the scan.  For Example, "C:\Temp\manual-macs.txt"

.Paramter MacList
    This specifies a list of MACs on the command line in the format 00:00:00:00:00:00, comma separated.

.Parameter Csv
    This sets a flag for output to a CSV file.  Default is $false, set by -Csv:$true.

.Parameter GridView
    This sets a flag to output result to the PowerShell GridView utility.  Default is $false, set by -GridView:$true.

.Parameter Email
    This sets a flag to email the CSV output to the specified recipient(s), comma separated email address list.  
    -Csv parameter is set $true if not already specified if -Email is used.  For Example, -Email "Info@domain.local".
    Email settings MUST be configured below for use in your environment, prior to importing module.

.EXAMPLE
    Gather details of all MACs on a single specified vCenter server. 
    Get-MacDetails -Vcenter "vc01" -AutoMac:$true

.NOTES
    Author: Jennifer Parsons
    Date:   January 19, 2017    
    Last updated: Jul 10, 2020
    Version 2.4
    REQUIREMENTS
    PowerShell v3 or greater
    vCenter 5.5
    PowerCLI 5.8 or later
    ESXi 5.5 or later

#>
function Get-MacDetails {
param (
    [CmdletBinding(DefaultParameterSetName="Vc")]
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Vcenter,
    [Parameter(Position=1)]
    [switch]$AutoMac = $false,
    [string]$MacFile,
    [string]$MacList,
    [switch]$Csv = $false,
    [switch]$GridView = $false,
    [string]$Email
    ) #end param
# Include the PowerCLI cmdlets to support scheduled task and native PowerShell exectution
Add-PSSnapin VMware.VimAutomation.Core
$vcs = @()
$vcs = $Vcenter.split(',')
$macarray = @()
$macarray = $MacList.split(',')
$folder = "C:\Temp\"
$csvpath = "C:\Temp\vmmac-details.csv"
$style = @"
<style>
BODY{font-family: Arial; font-size: 10pt;}
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
"@
$memberitems = New-Object System.Collections.ArrayList
If(Test-Path $csvpath) { Remove-Item $csvpath }
# If Email output was specified, here we build the message and send, cleaning up the temporary CSV file
Function Email {
    Write-Host "Email enabled, sending CSV output to $Email" -ForegroundColor Green
    $smtpsvr = "***PUT SMTP SERVERNAME HERE***"
    $mailfrom = "VMware VM MAC Details Report<***PUT FROM ADDRESS HERE**>"
    $subject = “Virtual Machine MAC Details From $vcs”
    $att = $csvpath
    if ($enablemail -match "yes")
    {
        Send-MailMessage -Attachments $att -From $mailfrom -To $Email -Subject $subject -Body “$body" -BodyAsHtml -SmtpServer $smtpsvr
    }
}
Foreach ($vc in $vcs) {
    # Connect to the vCenter Server
    Connect-VIServer $vc -WarningAction SilentlyContinue | Out-Null
    If ($AutoMac) {
        $macaddress = Get-VM | Get-NetworkAdapter | Sort MacAddress| Select -ExpandProperty MacAddress
    } ElseIf ($MacList) { $macaddress = $macarray }
        Else { $macaddress = Get-Content $MacFile }
    ForEach ($macs in $macaddress) {
        Write-Host "Search for $macs on $vc..." -ForegroundColor Yellow
        $result = Get-NetworkAdapter * |  Where {$_.MacAddress -like $macs} | Select Parent, MacAddress, NetworkName
        If ($result) {
            Write-Host "Found $macs, assigned to VM $vm..." -ForegroundColor Green
            $vm = Get-VM $result.Parent
            $vmhost = Get-VM $vm | Get-VMHost
            $ipaddress = $vm.Guest.IPAddress
            $ipaddress = $ipaddress -join ";"
            $memObj = New-Object System.Object
            $memObj | Add-Member -Type NoteProperty -name VirtualMachine -Value $vm
            $memObj | Add-Member -Type NoteProperty -name MacAddress -Value $result.MacAddress
            $memObj | Add-Member -Type NoteProperty -name NetworkName -Value $result.NetworkName
            $memObj | Add-Member -Type NoteProperty -name IPAddress -Value $ipaddress
            $memObj | Add-Member -Type NoteProperty -name VMHost -Value $vmhost
            $memObj | Add-Member -Type NoteProperty -name vCenter -Value $vc
            $memberitems.Add($memObj) | Out-Null
        }
        Else { Write-Host "$macs not found..." -ForegroundColor Red }
    }
    # Kill out connection to the vCenter server and any other connection that might be active! 
    Disconnect-VIServer -Server * -Confirm:$false
}
# Check if we're emailing the output and set logic
If ($Email) {
    $enablemail = "yes"
    $Html = $true;
    $Csv = $true;
}
# Check if we're building a CSV and do it if so
If ($Csv) {

    If(Test-Path $csvpath) { Remove-Item $csvpath }
    If (-Not (Test-Path $folder)) { 
        Write-Host "`nTemporary folder does not exist, creating $folder" -ForegroundColor Yellow
        New-Item -ItemType directory -Path $folder | Out-Null 
    }
    Write-Host "Writing to CSV file $csvpath..." -ForegroundColor Green
    $memberitems | Export-Csv "$csvpath" #-NoTypeInformation

}
# Prepare GridView output if requested
If ($GridView) {
    # Output list to on-screen GridView
    Write-Host "Outputting to GridView..." -ForegroundColor Green
    $memberitems | Out-GridView -Title "List of VM Snapshots"
}
# HTML formatted output
If ($Html) {
    $body = $memberitems | ConvertTo-Html -Head $style
}
# Send required variables to the Email Function
If ($enablemail) {
    Email ( $csvpath, $Email, $vcs, $enablemail, $body )
}
}
Export-ModuleMember -Function Get-MacDetails
