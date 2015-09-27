function Add-PlHostEntry
{
	[CmdletBinding()]
	param
	(
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('^[^\.]+$')]
		[string]$HostName,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ipaddress]$IpAddress,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Comment
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$IpAddress = $IpAddress.IPAddressToString
			if ($result = Get-PlHostEntry | where HostName -EQ $HostName)
			{
				throw "The hostname [$($HostName)] already exists in the host file with IP [$($result.IpAddress)]"
			}
			elseif ($result = Get-PlHostEntry | where IPAddress -EQ $IpAddress)
			{
				Write-Warning "The IP address [$($result.IPAddress)] already exists in the host file for the hostname [$($HostName)]. You should probabloy remove the old one hostname reference."
			}
			$vals = @(
				$IpAddress
				$HostName
			)
			if ($PSBoundParameters.ContainsKey('Comment')) {
				$vals += "# $Comment"
			}
			
			$hostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
			## If the hosts file doesn't end with a blank line, make it so
			if ((Get-Content -Path $hostsFilePath -Raw) -notmatch '\n$')
			{
				Add-Content -Path $hostsFilePath -Value ''
			}
			Add-Content -Path $HostFilePath -Value ($vals -join "`t")
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlHostEntry
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.PSCustomObject])]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$HostFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$sb = {
				param($HostFilePath)
				$regex = '^(?<ipAddress>[0-9.]+)[^\w]*(?<hostname>[^#\W]*)($|[\W]{0,}#\s+(?<comment>.*))'
				$matches = $null
				Get-Content -Path $HostFilePath | foreach {
					$null = $_ -match $regex
					if ($matches)
					{
						[pscustomobject]@{
							'IPAddress' = $matches.ipAddress
							'HostName' = $matches.hostname
							'Comment' = $matches.comment
						}
					}
					$matches = $null
				}
			}
			
			if ($ComputerName -eq (hostname))
			{
				& $sb $HostFilePath
			}
			else
			{
				$icmParams = @{
					'ComputerName' = $ComputerName
					'ScriptBlock' = $sb
					'ArgumentList' = $HostFilePath
				}
				if ($PSBoundParameters.ContainsKey('Credential'))
				{
					$icmParams.Credential = $Credential
				}
				Invoke-Command @icmParams
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-PlHostEntry
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('^[^\.]+$')]
		[string]$HostName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if (Get-PlHostEntry | where HostName -EQ $HostName)
			{
				$regex = "^(?<ipAddress>[0-9.]+)[^\w]*($HostName)(`$|[\W]{0,}#\s+(?<comment>.*))"
				$toremove = (Get-Content -Path $HostFilePath | select-string -Pattern $regex).Line
				## Safer to create a temp file
				$tempFile = [System.IO.Path]::GetTempFileName()
				(Get-Content -Path $HostFilePath | where { $_ -ne $toremove }) | Add-Content -Path $tempFile
				if (Test-Path -Path $tempFile -PathType Leaf)
				{
					Remove-Item -Path $HostFilePath
					Move-Item -Path $tempFile -Destination $HostFilePath
				}
			}
			else
			{
				Write-Warning -Message "No hostname found for [$($HostName)]"
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Set-PlHostEntry
{
	[CmdletBinding()]
	param
	(
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
				
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}