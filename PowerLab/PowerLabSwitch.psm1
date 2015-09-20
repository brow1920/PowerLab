function Get-PlSwitch
{
	[CmdletBinding()]
	param
	()
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$switch = (Get-PlConfigurationData).Environment.Switch
			Get-VMSwitch -ComputerName $Hostserver.name -Name $switch.Name -SwitchType $switch.Type -ErrorAction SilentlyContinue
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function New-PlSwitch
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = (Get-PlConfigurationData).Environment.Switch.Name,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Internal','External')]
		[string]$SwitchType	= (Get-PlConfigurationData).Environment.Switch.Type
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (-not (Get-VMSwitch -ComputerName $Hostserver.name -Name $Name -ea SilentlyContinue))
			{
				New-VMSwitch -ComputerName $HostServer.Name -Name $Name -SwitchType $SwitchType
			}
			else
			{
				Write-Verbose -Message "The PowerLab switch [$($Name)] already exists."	
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}