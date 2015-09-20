function ConvertTo-VirtualDisk
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.vhdx?$')]
		[string]$VhdPath,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$IsoFilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$AnswerFilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Dynamic', 'Fixed')]
		[string]$Sizing = (Get-PlDefaultVHDConfig).Sizing,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Edition = (Get-PlDefaultVMConfig).OS.Edition,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(512MB, 64TB)]
		[Uint64]$SizeBytes = (Invoke-Expression (Get-PlDefaultVHDConfig).Size),
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('VHD', 'VHDX')]
		[string]$VhdFormat = (Get-PlDefaultVHDConfig).Type,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$VHDPartitionStyle = (Get-PlDefaultVHDConfig).PartitionStyle
		
		
	)
	process
	{
		try
		{
			$convertFilePath = ((Get-PlConfigurationData).SelectSingleNode("//File[@Name='ISO to VHD Conversion Script' and @Location='HostServer']")).Path
			
			$sb = {
				. $using:convertFilePath
				$convertParams = @{
					SourcePath = $using:IsoFilePath
					SizeBytes = $using:SizeBytes
					Edition = $using:Edition
					VHDFormat = $using:VhdFormat
					VHDPath = $using:VhdPath
					VHDType = $using:Sizing
					VHDPartitionStyle = $using:VHDPartitionStyle
				}
				if ($PSBoundParameters.ContainsKey('AnswerFilePath')) {
					$convertParams.UnattendPath = $using:AnswerFilePath
				}
				Convert-WindowsImage @convertParams
			}
			Invoke-Command -ComputerName $HostServer.Name -Credential $HostServer.Credential -ScriptBlock $sb
		}
		catch
		{
			Write-Error -Message $_.Exception.Message
		}
	}
}

function New-PlVhd
{
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(512MB, 1TB)]
		[int64]$Size = (Invoke-Expression (Get-PlDefaultVHDConfig).Size),
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('VHD', 'VHDX')]
		[string]$Type = 'VHDX',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Path = (Get-PlDefaultVHDConfig).Path,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Dynamic','Fixed')]
		[string]$Sizing = (Get-PlDefaultVHDConfig).Sizing,
	
		[Parameter(Mandatory,ParameterSetName = 'OSInstall')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Windows Server 2012 R2 (x64)')]
		[string]$OperatingSystem,
	
		[Parameter(ParameterSetName = 'OSInstall')]
		[ValidateNotNullOrEmpty()]
		[string]$UnattendedXmlPath
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$sb = {
				if (-not (Test-Path -Path $using:Path -PathType Container))
				{
					$null = mkdir $using:Path	
				}
			}
			Invoke-Command -ComputerName $HostServer.Name -Credential $HostServer.Credential -ScriptBlock $sb
			
			$params = @{
				'SizeBytes' = $Size
			}
			if ($PSBoundParameters.ContainsKey('OperatingSystem'))
			{
				$cvtParams = $params + @{
					IsoFilePath = (Get-PlIsoFile -OperatingSystem $OperatingSystem).FullName
					VhdPath = "$Path\$Name.$Type"
					VhdFormat = $Type
					Sizing = $Sizing
				}
				if ($PSBoundParameters.ContainsKey('UnattendedXmlPath')) {
					$cvtParams.AnswerFilePath = $UnattendedXmlPath
				}
				ConvertTo-VirtualDisk @cvtParams
			}
			else
			{
				$params.ComputerName = $HostServer.Name
				$params.Path = "$Path\$Name.$Type"
				if ($Sizing -eq 'Dynamic')
				{
					$params.Dynamic = $true
				}
				elseif ($Sizing -eq 'Fixed')
				{
					$params.Fixed = $true
				}
				New-VHD @params
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVhd
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.vhdx?$')]
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
			$Path = (Get-PlDefaultVHDConfig).Path
			if ($PSBoundParameters.ContainsKey('Name')) {
				Get-Vhd -Path "$Path\$Name" -ComputerName $HostServer.Name
			}
			else
			{
				Get-ChildItem (ConvertTo-UncPath -ComputerName $HostServer.Name -LocalFilePath $Path) -File | foreach {
					Get-VHD -Path $_.FullName -ComputerName $HostServer.Name	
				}	
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-PlVhd
{
	[CmdletBinding(DefaultParameterSetName = 'InputObject', SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
		[ValidateNotNullOrEmpty()]
		[object]
		$InputObject,
		
		[Parameter(Mandatory, ParameterSetName = 'VM')]
		[ValidateNotNullOrEmpty()]
		[string]$VmName,
		
		[Parameter(Mandatory, ValueFromPipelineByPropertyName = 'VM')]
		[ValidateNotNullOrEmpty()]
		[string]$VhdName
		
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
