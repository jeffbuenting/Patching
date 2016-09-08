#------------------------------------------------------------------------------
# Install-Hotfixes.ps1
#
# installs the hotfixes located in the same path as the script. Including subdirectories
#------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------------

# ----- Get the path the script was started from
$Path = Split-Path -parent $MyInvocation.MyCommand.Definition

#-----Get list of hotfixes in the $Path directory
$HotFixes = Get-ChildItem -Path $Path -Recurse -Include "*.msu" | Sort-Object name

# ----- Get list of hotfixes installed
$InstalledHotfixes = Get-HotFix | out-string

if ( ( Test-Path -Path c:\temp ) -ne $True ) {
	New-Item -Path c:\temp -type directory	
}

$Reboot = $False

# ----- Process the list of Hotfixes
foreach ($Hotfix in $HotFixes ) {
	# ----- Check to see if hotfix is already installed
	# ---------- Get the Hotfix KB number from the name
	$V = $Hotfix.Name
	$V = $V.substring($V.indexof('-')+1)
	$V = $V.substring(0,$V.indexof('-'))
	$V		
	if ( $InstalledHotfixes.contains( $V )) {
			Write-Host "Already installed" -ForegroundColor Green
		}
		else {
			Write-Host "Installing..."
			$Command = $Path + '\' + $Hotfix.directory.name + '\' + $Hotfix.Name 
			Copy-Item $Command c:\temp
			$HFCMD = "c:\temp\" + $Hotfix.Name + " /quiet /norestart"
			$CMD = Start-Process -FilePath 'c:\Windows\System32\wusa.exe' -ArgumentList $HFCMD -passthru
			do{}until ($CMD.HasExited -eq $true)
			$ExitCode = $CMD.GetType().GetField("exitCode", "NonPublic,Instance").GetValue($CMD)
			
			Switch ( $ExitCode ) {
				0			{ 
						Write-Host "Done"
						$Reboot = $True
					}
				3			{ Write-Host "This update applies to a ROLE or Feature that is not installed on this computer" -ForegroundColor Yellow }
				3010		{ Write-Host "Hotfix for Windows is already installed on this computer." -ForegroundColor Yellow }
				-2145124329 { Write-Host "The Update is not applicable to your computer" -ForegroundColor Yellow }
				-2145124330 { Write-Host "Another Install is underway.  Please wait for that one to complete and restart this one." -ForegroundColor Yellow } 
				default 	{ Write-Host "Unknown Exit Code --> $ExitCode" -ForegroundColor Magenta }
			}
	}
}

Write-Host "Disabling TCP Offloading"
netsh int tcp set global chimney=disabled

Write-Host "Cleanig Orphaned registry entries created by LUNs being mounted / dispmounted repeatedly"
$RunCMD = '\\vbgov.com\deploy\Disaster_Recovery\Hyper-V Windows 2008\Patches\Host\DevNodeClean-x64.exe /r'
$CMD = Start-Process -FilePath '\\vbgov.com\deploy\Disaster_Recovery\Hyper-V Windows 2008\Patches\Host\DevNodeClean-x64.exe' -ArgumentList '/r' -PassThru -Wait -NoNewWindow
#do{}until ($CMD.HasExited -eq $true)


If ( $Reboot) { 
		Write-Host "Rebooting..." -foreground Red 
		# ----- Put Computer object in maintenance mode
		$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
		$Computer = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

		Import-Module -Name "\\vbgov.com\deploy\Disaster_Recovery\SCOM\Scripts\SCOMPSModule\SCOMPSModule.psm1" -argumentlist 'vbas022'
		
		set-MaintenanceMode $Computer ".5" "Rebooting after installing Hotfixes."
		# ----- Reboot
		Restart-Computer -Confirm
	} 
	else {
		Write-Host "Nothing to Install..." -ForegroundColor Green
}

