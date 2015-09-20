function New-PlVmGroup
{
	[CmdletBinding()]
	param
	(
	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVmGroup
{
	[CmdletBinding()]
	param
	(
	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-PlVmGroup
{
	[CmdletBinding(DefaultParameterSetName = 'InputObject', SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
		[ValidateNotNullOrEmpty()]
		[object]
		$InputObject,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'VMGroup')]
		[ValidateNotNullOrEmpty()]
		[string]$VmGroupName
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Test-PlVmGroup
{
	[CmdletBinding()]
	param
	(
	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}