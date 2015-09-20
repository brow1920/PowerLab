function Add-OperatingSystem
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.HyperV.PowerShell.VirtualMachine]$InputObject,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Windows Server 2012 R2 (x64)')]
		[string]$OperatingSystem
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$vhdName = "$($InputObject.Name).$((Get-PlDefaultVHDConfig).Type)"
			Write-Verbose -Message "VHD name is [$($vhdName)]"
			if (Test-PlVhd -Name $vhdName)
			{
				throw "There is already a VHD called [$($vhdName)]"	
			}
			$vhd = New-PlVhd -Name $vhdName -OperatingSystem $OperatingSystem
			Add-VMHardDiskDrive -ComputerName $hostserver.Name -Path $vhd.Path -VMName $InputObject.Name
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

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
		[string]$VHDPartitionStyle = (Get-PlDefaultVHDConfig).PartitionStyle,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
		
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
				if ($PassThru.IsPresent)
				{
					$convertParams.PassThru = $true	
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
		[ValidatePattern('\.vhdx?$')]
		[string]$Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(512MB, 1TB)]
		[int64]$Size = (Invoke-Expression (Get-PlDefaultVHDConfig).Size),
		
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
					VhdPath = "$Path\$Name"
					VhdFormat = ([system.io.path]::GetExtension($Name) -replace '^.')
					Sizing = $Sizing
					PassThru = $true
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
		[string]$Path = (Get-PlDefaultVHDConfig).Path,
		
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
			if ($PSBoundParameters.ContainsKey('Name'))
			{
				Write-Verbose -Message "Checking for VHD at [$Path\$Name]"
				try
				{
					Get-Vhd -Path "$Path\$Name" -ComputerName $HostServer.Name
				}
				catch [System.Management.Automation.ActionPreferenceStopException]
				{
					
				}
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
	[CmdletBinding(DefaultParameterSetName = 'InputObject')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Vhd.PowerShell.VirtualHardDisk]$InputObject,
		
		[Parameter(ParameterSetName = 'Path')]
		[ValidateNotNullOrEmpty()]
		[ValidatePattern('\.vhdx?$')]
		[string]$Path = (Get-PlDefaultVHDConfig).Path
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
		function ConvertTo-LocalPath
		{	
			[CmdletBinding()]
			[OutputType([System.String])]
			param
			(
				[Parameter(Mandatory)]
				[ValidateNotNullOrEmpty()]
				[string]$Path
			)
			
			$UncPathSpl = $Path.Split('\')
			$Drive = $UncPathSpl[3].Trim('$')
			$FolderTree = $UncPathSpl[4..($UncPathSpl.Length - 1)]
			'{0}:\{1}' -f $Drive, ($FolderTree -join '\')
		}
		
	}
	process
	{
		try
		{
			$icmParams = @{
				'ComputerName' = $HostServer.Name
				'Credential' = $HostServer.Credential
			}
			if ($PSBoundParameters.ContainsKey('InputObject'))
			{
				if ($InputObject.Path.StartsWith('\\'))
				{
					$Path = ConvertTo-LocalPath -Path $InputObject.Path
				}
				else
				{
					$Path = $InputObject.Path
				}
			}
			
			Invoke-Command @icmParams -ScriptBlock { Remove-Item -Path $using:Path -Force }
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Test-PlVhd
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if (Get-PlVhd -Name $Name)
			{
				$true
			} else {
				$false	
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}