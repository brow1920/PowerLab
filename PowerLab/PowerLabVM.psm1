function New-PlVm
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Switch = (Get-PlConfigurationData).Environment.Switch.Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(512MB, 64GB)]
		[int64]$MemoryStartupBytes = (Invoke-Expression (Get-PlDefaultVMConfig).StartupMemory),
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
			$downloadedIsoOses = (Get-PlConfigurationData).Configuration.ISOs.ISO.OS
			if ($_ -notin $downloadedIsoOses)
			{
				throw "Invalid operating system used. Valid values are [$($downloadedIsoOses -join ',')]"
			}
			else
			{
				$true	
			}
		})]
		[string]$OperatingSystem = (Get-PlDefaultVMConfig).OS.Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('ServerStandardCore')]
		[string]$Edition = 'ServerStandardCore',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('1','2')]
		[int]$Generation = (Get-PlDefaultVMConfig).Generation,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$VMPath = (Get-PlDefaultVMConfig).Path,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$InstallOS,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$AsJob
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not $PSBoundParameters.ContainsKey('Name'))
			{
				$os = (Get-PlDefaultVMConfig).Hostnames.SelectSingleNode("//Hostname[@OS='$OperatingSystem']")
				if (-not $os)
				{
					throw "No default hostname set in configuration for OS [$($OperatingSystem)]"	
				}
				$os = $os | where { $_.Edition -eq $Edition }
				$osPrefix = $os.Prefix
				$existingOSNames = (Get-PlVm).Name | where { $_ -match "^$osPrefix" } | Sort -Descending
				if (-not $existingOSNames)
				{
					$latestNum = 0
				}
				else
				{
					if ($existingOSNames -is [string])
					{
						[int]$latestNum = [regex]::Matches($existingOSNames, '(\d+)$').Groups[0].Value
					}
					else
					{
						[int]$latestNum = [regex]::Matches($existingOSNames[0], '(\d+)$').Groups[0].Value
					}
					
				}
				$Name = '{0}{1}' -f $osPrefix, ($latestNum + 1).ToString('00')
			}
			$vmParams = @{
				'ComputerName' = $HostServer.Name
				'Name' = $Name
				'Path' = $VMPath
				'MemoryStartupBytes' = $MemoryStartupBytes
				'Switch' = $Switch
				'Generation' = $Generation
			}
			New-VM @vmParams
			if ($InstallOs.IsPresent)
			{
				
			}
		}
		catch
		{
			Write-Error  "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
		}
	}
}

function Get-PlVm
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSBoundParameters.ContainsKey('Name'))
			{
				Get-VM -ComputerName $HostServer.Name -Name $Name
			}
			else
			{
				Get-VM -ComputerName $HostServer.Name
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVmDeploymentStatus
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

function Remove-PlVM
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name
		
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$removeParams = @{ }
			if ($PSBoundParameters.ContainsKey('Force')) {
				$removeParams.Force = $true
			}
			Get-VM -ComputerName $HostServer.Name -Name $Name | Remove-VM
			$vmPath = (Get-PlDefaultVMConfig).Path
			$icmParams = @{
				'ComputerName' = $HostServer.Name
				'Credential' = $HostServer.Credential
				'ScriptBlock' = { Get-ChildItem -Path $using:vmPath -Include '*.vhd*' | Remove-Item -Force }
			}
			Invoke-Command @icmParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}