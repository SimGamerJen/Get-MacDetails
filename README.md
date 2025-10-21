# Get-MacDetails (PowerShell Module)

Query one or more **VMware vCenter** servers for **virtual machines by MAC address** and return key details (VM name, network name, IPs, host, and vCenter). Output can be written to CSV, shown in an on-screen GridView, and/or emailed as an HTML report.

> **Requires:** VMware PowerCLI (`VMware.VimAutomation.Core`) and access to the target vCenter(s).

---

## Features

* Search **one or more vCenters** for VMs matching a list of **MAC addresses**
* Accept MACs via:

  * `-MacFile` (path to a text file, one MAC per line)
  * `-MacList` (comma-separated inline list)
  * `-AutoMac` (scan all VMs/adapters in the vCenter(s))
* Export results to **CSV** (hard-coded path: `C:\Temp\vmmac-details.csv`)
* Show results in an **Out-GridView** (optional)
* Generate **HTML** and **email** the report (SMTP values are placeholders you can set in the module)

**Returned fields** (per match):

* `VirtualMachine`
* `MacAddress`
* `NetworkName`
* `IPAddress` (semicolon-separated if multiple; requires VMware Tools/guest info)
* `VMHost`
* `vCenter`

---

## Installation

Clone or download this repo, then import the module:

```powershell
Import-Module .\Get-MacDetails.psm1
```

> The module uses `Add-PSSnapin VMware.VimAutomation.Core`, which is available in **Windows PowerShell** with PowerCLI installed. If you prefer newer PowerShell 7+/module syntax, you can adapt the import to `Import-Module VMware.PowerCLI`.

---

## Usage

### Parameters

| Parameter   | Type     | Required | Description                                                                                                                                 |
| ----------- | -------- | -------: | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `-Vcenter`  | `string` |        ✅ | Comma-separated vCenter names/FQDNs. Example: `"vc01,vc02"`.                                                                                |
| `-AutoMac`  | `switch` |          | If set, enumerate all MAC addresses from all VMs in the specified vCenter(s).                                                               |
| `-MacFile`  | `string` |          | Path to a text file containing one MAC per line.                                                                                            |
| `-MacList`  | `string` |          | Comma-separated MAC list. Example: `"00:50:56:AA:BB:CC,00:50:56:DD:EE:FF"`.                                                                 |
| `-Csv`      | `switch` |          | Export results to `C:\Temp\vmmac-details.csv`. Folder will be created if missing; existing file is overwritten.                             |
| `-GridView` | `switch` |          | Show results in `Out-GridView` (Windows only).                                                                                              |
| `-Email`    | `string` |          | If provided, enables email/HTML/CSV output and sends the HTML report to this address. **Requires editing SMTP placeholders in the module.** |

> The module splits `-Vcenter` and `-MacList` on commas internally.

---

### Examples

**1) Search multiple vCenters with a file of MACs and export to CSV**

```powershell
Import-Module .\Get-MacDetails.psm1
Get-MacDetails -Vcenter "vc01,vc02" -MacFile .\macs.txt -Csv
```

**2) Inline MAC list and show an on-screen GridView**

```powershell
Get-MacDetails -Vcenter "vc01" `
  -MacList "00:50:56:AA:BB:CC,00:50:56:DD:EE:FF" `
  -GridView
```

**3) Enumerate all MACs from the vCenter and export**

```powershell
Get-MacDetails -Vcenter "vc01" -AutoMac -Csv
```

**4) Email the HTML report (and also write CSV automatically)**

```powershell
# Edit SMTP settings in the module first (see “Email configuration”)
Get-MacDetails -Vcenter "vc01,vc02" -MacFile .\macs.txt -Email "ops@example.com"
```

---

## Output

**CSV path:** `C:\Temp\vmmac-details.csv` (overwritten each run)

**GridView:** If `-GridView` is used, results are shown in a window titled “List of VM Snapshots” (module uses that title string).

**Email/HTML:** If `-Email` is specified:

* HTML is generated from the results with a simple CSS header
* CSV is always written
* An email is sent with the HTML body and CSV attached

---

## Email configuration

Inside the module there’s an `Email` helper function with **placeholders** you should replace:

```powershell
$smtpsvr  = "***PUT SMTP SERVERNAME HERE***"
$mailfrom = "VMware VM MAC Details Report<***PUT FROM ADDRESS HERE**>"
$subject  = "Virtual Machine MAC Details From $vcs"
```

It uses `Send-MailMessage` (works in Windows PowerShell; note it’s deprecated in newer PowerShell versions — swap to your preferred mail cmdlet if needed).

---

## Authentication & Permissions

* The module calls `Connect-VIServer` for each vCenter in `-Vcenter`. You’ll be **prompted** for credentials (unless cached or handled by your environment).
* You need permissions to read VM/adapter/host/guest properties.
* `IPAddress` values come from `$vm.Guest.IPAddress`, which requires guest info (typically VMware Tools). This may be empty if Tools are not running.

---

## Requirements

* **Windows PowerShell 5.1** (tested context implied by `Add-PSSnapin`)
* **VMware PowerCLI** (for `VMware.VimAutomation.Core`)
* Access to the target **vCenter(s)**
* **Windows** if using `-GridView` (Out-GridView)

---

## Limitations & Notes

* CSV path and temp folder are **hard-coded**:

  * Folder: `C:\Temp\`
  * CSV: `C:\Temp\vmmac-details.csv`
* Existing CSV is **deleted** before export.
* `-AutoMac` enumerates all VM NICs in the connected vCenter(s) — useful for full inventory, but can be slow on large estates.
* IP addresses are **semicolon-joined** if multiple are reported for a VM.
* The module uses **snap-ins** not `Import-Module` for PowerCLI; if you prefer the newer module-based approach, adjust the import line.

---

## Quick Troubleshooting

* **“The term ‘Connect-VIServer’ is not recognized”**
  Install/import VMware PowerCLI and ensure `VMware.VimAutomation.Core` is available.

* **No IP addresses in output**
  Ensure VMware Tools/guest info is available for those VMs.

* **Out-GridView doesn’t open**
  Run in Windows PowerShell, not PowerShell 7 (or install compatibility components), and don’t run in headless environments.

* **Email not sent**
  Update the SMTP server and sender address in the `Email` function. Consider replacing `Send-MailMessage` with a modern mail cmdlet if your environment blocks it.

---

## License

Add your preferred license here (e.g., MIT).

---

## Author

SimGamerJen

