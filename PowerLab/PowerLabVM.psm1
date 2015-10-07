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
		[int]$Count = 1,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Switch = (Get-PlConfigurationData).Environment.Switch.Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(512MB, 64GB)]
		[int64]$MemoryStartupBytes = (Invoke-Expression (Get-PlDefaultVMConfig).StartupMemory),
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('1','2')]
		[int]$Generation = (Get-PlDefaultVMConfig).Generation,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Path = (Get-PlDefaultVMConfig).Path,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Windows Server 2012 R2 (x64)')]
		[string]$OperatingSystem = (Get-PlDefaultVMConfig).OS.Name,
	
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
				'Path' = $Path
				'MemoryStartupBytes' = $MemoryStartupBytes
				'Switch' = $Switch
				'Generation' = $Generation
			}
			if ($PSBoundParameters.ContainsKey('AsJob')) {
				$vmParams.AsJob = $true
			}
			
			$vm = New-VM @vmParams
			#Add-PlVmDatabaseEntry -Name $Name -CreationDate (Get-Date).ToString()
			$vm
			if ($Count -gt 1)
			{
				for ($i = 1; $i -lt $Count; $i++)
				{
					New-PlVm	
				}
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
			$gvParams = @{
				'ComputerName' = $HostServer.Name	
			}
			if ($PSBoundParameters.ContainsKey('Name'))
			{
				$gvParams.Name = $Name
			}
			Get-VM @gvParams
			
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
		[string]$Name,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$RemoveAttachedVhd
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$vm = Get-VM -ComputerName $HostServer.Name -Name $Name
			$diskPath = $vm.HardDrives.Path
			$vm | Remove-VM -Force
			$vmPath = (Get-PlDefaultVMConfig).Path
			$icmParams = @{
				'ComputerName' = $HostServer.Name
				'Credential' = $HostServer.Credential
				'ScriptBlock' = { Remove-Item -Path "$using:vmPath\$using:Name" -Force -Recurse }
			}
			Invoke-Command @icmParams
			
			if ($RemoveAttachedVhd.IsPresent)
			{
				if (-not $diskPath)
				{
					Write-Verbose -Message "There was no disk attached to [$($Name)]"
				}
				else
				{
					Write-Verbose -Message "Removing disk [$($diskPath)]..."
					Get-PlVhd -Path $diskPath | Remove-PlVhd
				}
			}
			
			Remove-PlDatabaseRow -Table VMs -Column Name -Value $Name
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}