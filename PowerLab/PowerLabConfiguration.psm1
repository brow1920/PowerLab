## The registry key path to where various configuration values are stored
$RegistryKeyConfigPath = "HKLM:\Software\$($Project.Name)"

## The registry value name that contains the file path to the configuration file
$RegistryConfigValue = 'Configuration'

function ConvertTo-UncPath
{
	<#
		.SYNOPSIS
			A simple function to convert a local file path and a computer name to a network UNC path.

		.PARAMETER LocalFilePath
			A file path ie. C:\Windows\somefile.txt

		.PARAMETER Computername
			One or more computers in which the file path exists on
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$LocalFilePath,
		
		[Parameter(Mandatory)]
		[string[]]$ComputerName
	)
	process
	{
		try
		{
			foreach ($Computer in $ComputerName)
			{
				$RemoteFilePathDrive = ($LocalFilePath | Split-Path -Qualifier).TrimEnd(':')
				"\\$Computer\$RemoteFilePathDrive`$$($LocalFilePath | Split-Path -NoQualifier)"
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function New-PlDatabase
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Instance = '.',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Database = $Project.Name,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Table = 'VMs'
		
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
			$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $Instance
			$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($server, $Database)
			$db.Create()
						
			$dtint = [Microsoft.SqlServer.Management.Smo.Datatype]::Int
			$dtvchar100 = [Microsoft.SqlServer.Management.Smo.Datatype]::NVarChar(100)
			$dtdatetm = [Microsoft.SqlServer.Management.Smo.Datatype]::DateTime
						
			$tbl = New-Object ('Microsoft.SqlServer.Management.Smo.Table') ($Database, $Table, 'dbo')
						
			#Create the ID column
			$clId = new-object ('Microsoft.SqlServer.Management.Smo.Column') ($tbl, 'ID', $dtint)
			$clId.Identity = $true
			$clId.IdentitySeed = 1
			$clId.IdentityIncrement = 1
			$tbl.Columns.Add($clId)
			
			$cols = @(
			@{ 'Name' = 'Name'; 'Type' = $dtvchar100 }
			@{ 'Name' = 'OperatingSystem'; 'Type' = $dtvchar100 }
			@{ 'Name' = 'Group'; 'Type' = $dtvchar100 }
			@{ 'Name' = 'DeployedOn'; 'Type' = $dtdatetm }
			)
			foreach ($c in $cols)
			{
				$col = new-object ('Microsoft.SqlServer.Management.Smo.Column') ($tbl, $c.Name, $c.Type)
				$col.Nullable = $false
				$tbl.Columns.Add($col)
			}
			
			$pk = new-object ('Microsoft.SqlServer.Management.Smo.Index') ($tbl, "PK_$($Project.Name)")
			$pk.IndexKeyType = 'DriPrimaryKey'
			$pk.IsClustered = $true
			$indexCol = new-object ('Microsoft.SqlServer.Management.Smo.IndexedColumn') ($pk, 'ID')
			$pk.IndexedColumns.Add($indexCol)
			$tbl.Indexes.Add($pk)
						
			#Create the table
			$tbl.Create()
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlDefaultVHDConfig
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
			(Get-PlConfigurationData).DefaultVHDConfig
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlDefaultDatabaseConfig
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
			(Get-PlConfigurationData).Configuration.Database
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlDefaultVMConfig
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
			(Get-PlConfigurationData).DefaultVMConfig
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Test-PlDatabase
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Instance = '.',
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Database = $Project.Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
			$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $Instance
			if (-not $server.Databases[$Database])
			{
				$false
			}
			else
			{
				$true	
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Invoke-PlIsoDownload
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
			$startBitsTransferParams = @{
				Source = $Uri;
				Destination = $DestinationPath;
				TransferType = 'Download';
				DisplayName = $localized.DownloadingActivity -f $destinationFilename;
				Description = $Uri;
				Priority = 'Foreground';
			}
			WriteVerbose ($localized.DownloadingResource -f $Uri, $DestinationPath);
			Start-BitsTransfer @startBitsTransferParams -ErrorAction Stop;
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlConfigurationData
{
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(ParameterSetName = 'ConfigurationFolder')]
		[ValidateNotNullOrEmpty()]
		[string]$ConfigurationFolder,

		[Parameter(ParameterSetName = 'VM')]
		[ValidateNotNullOrEmpty()]
		[string[]]$VM,
		
		[Parameter(ParameterSetName = 'Domain')]
		[ValidateNotNullOrEmpty()]
		[switch]$Domain,
	
		[Parameter(ParameterSetName = 'HostServer')]
		[ValidateNotNullOrEmpty()]
		[switch]$HostServer
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$xConfig = [xml](Get-Content -Path (Get-PlConfigurationFile).FullName)
			$xConfig = $xConfig.($Project.Name)
			if ($PSBoundParameters.ContainsKey('VM'))
			{
				$xConfig.VirtualMachines.VM | where { $_.Name -in $VM }
			}
			elseif ($PSBoundParameters.ContainsKey('ConfigurationFolder'))
			{
				$xConfig.Configuration.Folders.SelectSingleNode("//Folder[@Name='$ConfigurationFolder']")
			}
			elseif ($PSBoundParameters.ContainsKey('HostServer'))
			{
				$xConfig.HostServer	
			}
			elseif ($Domain.IsPresent)
			{
				$xConfig.Domain
			}
			else
			{
				$xConfig
			}
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVMConfiguration
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$VM
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if ($PSBoundParameters.ContainsKey('VM')) {
				Get-PlConfigurationData -VM $VM
			}
			else
			{
				(Get-PlConfigurationData).VirtualMachines.VM
			}
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlDomainConfiguration
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
			Get-PlConfigurationData -Domain
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlHostServerConfiguration
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
			$config = Get-PlConfigurationData -HostServer
			$config | Add-Member -MemberType NoteProperty -Name 'Credential' -Value (Get-PlHostServerCredential)
			$config
			
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlConfigurationFolder
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
				Get-PlConfigurationData -ConfigurationFolder $Name
			}
			else
			{
				(Get-PlConfigurationData).Configuration.Folders.SelectNodes("//Folder")
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlConfigurationFile
{
	[CmdletBinding()]
	[OutputType([System.IO.FileInfo])]
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
			Write-Verbose -Message "Finding value of [$($RegistryConfigValue)] at path [$($RegistryKeyConfigPath)]"
			$path = (Get-ItemProperty -Path $RegistryKeyConfigPath -Name $RegistryConfigValue).$RegistryConfigValue
			Get-Item -Path $path
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Install-RSAT
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Url = 'http://download.microsoft.com/download/1/8/E/18EA4843-C596-4542-9236-DE46F780806E/Windows8.1-KB2693643-x64.msu'
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
		
		function Get-InstalledSoftware
		{
			<#
			.SYNOPSIS
				Retrieves a list of all software installed
			.EXAMPLE
				Get-InstalledSoftware
				
				This example retrieves all software installed on the local computer
			.PARAMETER Name
				The software title you'd like to limit the query to.
			.PARAMETER Guid
				The software GUID you'e like to limit the query to
			#>
			[CmdletBinding()]
			param (
				
				[Parameter()]
				[ValidateNotNullOrEmpty()]
				[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })]
				[string[]]$ComputerName,
				
				[Parameter()]
				[ValidateNotNullOrEmpty()]
				[pscredential]$Credential,
				
				[string]$Name,
				
				[ValidatePattern('\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b')]
				[string]$Guid
			)
			process
			{
				try
				{
					$scriptBlock = {
						$UninstallKeys = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
						New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
						$UninstallKeys += Get-ChildItem HKU: | where { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | foreach { "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall" }
						if (-not $UninstallKeys)
						{
							Write-Warning -Message 'No software registry keys found'
						}
						else
						{
							foreach ($UninstallKey in $UninstallKeys)
							{
								$friendlyNames = @{
									'DisplayName' = 'Name'
									'DisplayVersion' = 'Version'
								}
								Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
								if ($PSBoundParameters.ContainsKey('Name'))
								{
									$WhereBlock = { $_.GetValue('DisplayName') -like "$Name*" }
								}
								elseif ($PSBoundParameters.ContainsKey('GUID'))
								{
									$WhereBlock = { $_.PsChildName -eq $Guid }
								}
								else
								{
									$WhereBlock = { $_.GetValue('DisplayName') }
								}
								$SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object $WhereBlock
								if (-not $SwKeys)
								{
									Write-Verbose -Message "No software keys in uninstall key $UninstallKey"
								}
								else
								{
									foreach ($SwKey in $SwKeys)
									{
										$output = @{ }
										foreach ($ValName in $SwKey.GetValueNames())
										{
											if ($ValName -ne 'Version')
											{
												$output.InstallLocation = ''
												if ($ValName -eq 'InstallLocation' -and ($SwKey.GetValue($ValName)) -and (@('C:', 'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64') -notcontains $SwKey.GetValue($ValName).TrimEnd('\')))
												{
													$output.InstallLocation = $SwKey.GetValue($ValName).TrimEnd('\')
												}
												[string]$ValData = $SwKey.GetValue($ValName)
												if ($friendlyNames[$ValName])
												{
													$output[$friendlyNames[$ValName]] = $ValData.Trim() ## Some registry values have trailing spaces.
												}
												else
												{
													$output[$ValName] = $ValData.Trim() ## Some registry values trailing spaces
												}
											}
										}
										$output.GUID = ''
										if ($SwKey.PSChildName -match '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b')
										{
											$output.GUID = $SwKey.PSChildName
										}
										New-Object –TypeName PSObject –Prop $output
									}
								}
							}
						}
					}
					if ($PSBoundParameters.ContainsKey('ComputerName'))
					{
						$icmParams = @{
							'ComputerName' = $ComputerName
							'ScriptBlock' = $scriptBlock
						}
						if ($PSBoundParameters.ContainsKey('Credential'))
						{
							$icmParams.Credential = $Credential
						}
						Invoke-Command @icmParams
					}
					else
					{
						& $scriptBlock
					}
				}
				catch
				{
					Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
				}
			}
		}
	}
	process {
		try
		{
			if (-not (Get-InstalledSoftware | where { $_.Name -like '*Remote Server Administration Tools*' }))
			{
				#region RSAT download
				$downloadedFilePath = "$env:TEMP\$($Url | Split-Path -Leaf)"
				if (-not (Test-Path -Path $downloadedFilePath -PathType Leaf))
				{
					(New-Object System.Net.WebClient).DownloadFile($Url, $downloadedFilePath)
				}
				else
				{
					Write-Verbose -Message "The file [$($downloadedFilePath)] already exists. Using that one to install RSAT."
				}
				#endregion
				
				#region RSAT install
				Start-Process -FilePath 'WUSA.exe' -Args "$downloadedFilePath /QUIET /NORESTART"
				#endregion
			}
			else
			{
				Write-Verbose -Message 'RSAT is already installed.'
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Save-PlHostServerCredential
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$OutFilePath = "$PSScriptRoot\HostServerCredential.xml"
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$Credential | Export-CliXml $OutFilePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlHostServerCredential
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath = "$PSScriptRoot\HostServerCredential.xml"
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			Import-Clixml -Path $FilePath
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Test-PlHostServerCredential
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath = "$PSScriptRoot\HostServerCredential.xml"
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		Test-Path -Path $FilePath -PathType Leaf
	}
}

function New-PlConfigurationFile
{
	[CmdletBinding()]
	[OutputType([System.Xml.XmlDocument])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ -not (Test-Path -Path $_ -PathType Leaf) })]
		[string]$FilePath,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		Write-Verbose -Message "Creating the configuration file [$($FilePath)]"
		[System.XML.XMLDocument]$xmlDoc = New-Object System.XML.XMLDocument
		[System.XML.XMLElement]$xmlRoot = $xmlDoc.CreateElement($Project.Name)
		$null = $xmlDoc.AppendChild($xmlRoot)
		$xmlDoc.Save($FilePath)
	}
}

function New-PlConfigurationRegistry
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ConfigFilePath
			
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if (-not (Test-Path -Path $RegistryKeyConfigPath))
			{
				Write-Verbose -Message "Creating the registry key [$($Project.Name)] at in key path [$($RegistryKeyConfigPath | Split-Path -Parent))]"
				$null = New-Item -Path ($RegistryKeyConfigPath | Split-Path -Parent) -Name $Project.Name
			}
			if (-not (Get-ItemProperty $RegistryKeyConfigPath -Name $RegistryConfigValue -ea SilentlyContinue))
			{
				Write-Verbose -Message "Creating the registry value [$($RegistryConfigValue)]"
				$null = New-ItemProperty -Path $RegistryKeyConfigPath -Name $RegistryConfigValue -Value $ConfigFilePath -Force
			}
			if ($PassThru.IsPresent)
			{
				[xml](Get-Content -Path $ConfigFilePath)
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Send-FileOverWinRM
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Destination,
		
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)
	foreach ($p in $Path)
	{
		try
		{
			if (Test-UncPath -Path $p)
			{
				Write-Verbose -Message "[$($p)] is a UNC path. Copying locally first"
				Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine')) -Force -Recurse
				$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
			}
			if (Test-Path -Path $p -PathType Container)
			{
				Write-Verbose -Message "[$($p)] is a folder. Sending all files"
				$files = Get-ChildItem -Path $p -File -Recurse
				$sendFileParamColl = @()
				foreach ($file in $Files)
				{
					$sendParams = @{
						'Session' = $Session
						'Path' = $file.FullName
					}
					if ($file.DirectoryName -ne $p) ## It's a subdirectory
					{
						$subdirpath = $file.DirectoryName.Replace("$p\", '')
						$sendParams.Destination = "$Destination\$subDirPath"
					}
					else
					{
						$sendParams.Destination = $Destination
					}
					$sendFileParamColl += $sendParams
				}
				foreach ($paramBlock in $sendFileParamColl)
				{
					Send-File @paramBlock
				}
			}
			else
			{
				Write-Verbose -Message "Starting WinRM copy of [$($p)] to [$($Destination)]"
				# Get the source file, and then get its contents
				$sourceBytes = [System.IO.File]::ReadAllBytes($p);
				$streamChunks = @();
				
				# Now break it into chunks to stream.
				$streamSize = 1MB;
				for ($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize)
				{
					$remaining = $sourceBytes.Length - $position
					$remaining = [Math]::Min($remaining, $streamSize)
					
					$nextChunk = New-Object byte[] $remaining
					[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
					$streamChunks +=, $nextChunk
				}
				$remoteScript = {
					if (-not (Test-Path -Path $using:Destination -PathType Container))
					{
						$null = New-Item -Path $using:Destination -Type Directory -Force
					}
					$fileDest = "$using:Destination\$($using:p | Split-Path -Leaf)"
					## Create a new array to hold the file content
					$destBytes = New-Object byte[] $using:length
					$position = 0
					
					## Go through the input, and fill in the new array of file content
					foreach ($chunk in $input)
					{
						[GC]::Collect()
						[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
						$position += $chunk.Length
					}
					
					[IO.File]::WriteAllBytes($fileDest, $destBytes)
					
					Get-Item $fileDest
					[GC]::Collect()
				}
				
				# Stream the chunks into the remote script.
				$Length = $sourceBytes.Length
				$streamChunks | Invoke-Command -Session $Session -ScriptBlock $remoteScript
				Write-Verbose -Message "WinRM copy of [$($p)] to [$($Destination)] complete"
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Set-WorkgroupConnectivity
{
	[CmdletBinding()]
	param
	(
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
		
		function Test-PsRemoting
		{
			param (
				[Parameter(Mandatory = $true)]
				$computername
			)
			
			try
			{
				$errorActionPreference = "Stop"
				$result = Invoke-Command -ComputerName $computername { 1 }
			}
			catch
			{
				return $false
			}
			
			## I’ve never seen this happen, but if you want to be
			## thorough….
			if ($result -ne 1)
			{
				Write-Verbose "Remoting to $computerName returned an unexpected result."
				return $false
			}
			$true
		}
		
		function Add-TrustedHostComputer
		{
			[CmdletBinding()]
			param
			(
				[Parameter()]
				[ValidateNotNullOrEmpty()]
				[string[]]$ComputerName
				
			)
			try
			{
				foreach ($c in $ComputerName)
				{
					Write-Verbose -Message "Adding [$($c)] to client WSMAN trusted hosts"
					$TrustedHosts = (Get-Item -Path WSMan:\localhost\Client\TrustedHosts).Value
					if (-not $TrustedHosts)
					{
						Set-Item -Path wsman:\localhost\Client\TrustedHosts -Value $c -Force
					}
					elseif (($TrustedHosts -split ',') -notcontains $c)
					{
						$TrustedHosts = ($TrustedHosts -split ',') + $c
						Set-Item -Path wsman:\localhost\Client\TrustedHosts -Value ($TrustedHosts -join ',') -Force
					}
				}
			}
			catch
			{
				Write-Error $_.Exception.Message
			}
		}
		
		function Add-ToLocalGroup
		{
			[CmdletBinding()]
			param
			(
				[Parameter(Mandatory)]
				[ValidateNotNullOrEmpty()]
				[string]$Principal,
				
				[Parameter(Mandatory)]
				[ValidateNotNullOrEmpty()]
				[string]$GroupName,
				
				[Parameter()]
				[ValidateNotNullOrEmpty()]
				[string]$ComputerName,
				
				[Parameter()]
				[ValidateNotNullOrEmpty()]
				[pscredential]$Credential
				
			)
			try
			{
				$Principal = $Principal.Replace('\', '/')
				$scriptBlock = {
					$group = [ADSI]"WinNT://$using:ComputerName/$using:GroupName,group"
					$group.add("WinNT://$using:ComputerName/$using:Principal")
				}
				
				$invParams = @{
					'ComputerName' = $ComputerName
					'ScriptBlock' = $scriptBlock
				}
				
				if ($PSBoundParameters.ContainsKey('Credential'))
				{
					$invParams.Credential = $Credential
				}
				Invoke-Command @invParams
			}
			catch
			{
				Write-Error $_.Exception.Message
			}
		}
	}
	process {
		try
		{
			$hostServer = Get-PlHostServerConfiguration
			
			#region Add the host server hostname to local hosts file
			if (-not (Get-PlHostEntry | where { $_.HostName -eq $hostServer.Name -and $_.IPAddress -eq $hostServer.IPAddress }))
			{
				Write-Verbose -Message "Host file entry for [$($hostServer.Name)] doesn't exist. Adding..."
				Add-PlHostEntry -HostName $hostServer.Name -IpAddress $hostserver.IPAddress
			}
			#endregion
			
			#region Enable remoting on the host server
			$cred = Get-PlHostServerCredential
			$wmiParams = @{
				'ComputerName' = $hostServer.Name
				'Credential' = $cred
				'Class' = 'Win32_Process'
				'Name' = 'Create'
				'Args' = "c:\windows\system32\winrm.cmd quickconfig -quiet"
			}
			$process = Invoke-WmiMethod @wmiParams
			if ($process.ReturnValue -ne 0)
			{
				throw 'Enabling WinRM on host server failed'
			}
			else
			{
				Write-Verbose -Message 'Successfully enabled WinRM on host server'	
			}
			#endregion
			
			#region Add the host server to the trusted hosts
			Add-TrustedHostComputer -ComputerName $hostServer.Name
			#endregion
			
			#region Configure settings to allow for remote Hyper-V manager
			$sb = {
				Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management'
				Enable-NetFirewallRule -DisplayGroup 'Remote Event Log Management'
				Enable-NetFirewallRule -DisplayGroup 'Remote Volume Management'
				Set-Service VDS -StartupType Automatic
			}
			Invoke-Command -ComputerName $hostServer.Name -Credential $cred -ScriptBlock $sb
			
			#region Allow anonymous DCOM connections
			$group = [ADSI]"WinNT://$($hostServer.Name)/Distributed COM Users"
			$members = @($group.Invoke("Members")) | foreach {
				$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
			}
			if ($members -notcontains 'ANONYMOUS LOGON')
			{
				$grpParams = @{
					'ComputerName' = $hostServer.Name
					'Credential' = $cred
					'GroupName' = 'Distributed COM Users'
					'Principal' = 'NT AUTHORITY\ANONYMOUS LOGON'
				}
				
				Add-ToLocalGroup @grpParams
			}
			#endregion
			#endregion
			
			Enable-NetFirewallRule -DisplayGroup 'Remote Volume Management'
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

#region Commented out XML manipulation functions
#function Set-PlConfiguration
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory, ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[System.Xml.XmlDocument]$InputObject,
#		
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[string]$InstallFolderPath,
#		
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[switch]$PassThru
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			
#			if ($PSBoundParameters.ContainsKey('InstallFolderPath'))
#			{
#				## Create the tag if it doesn't exist
#				if (-not $InputObject.FirstChild.SelectSingleNode('InstallFolder'))
#				{
#					
#				}
#				## Set the attribute
#				$InputObject.FirstChild.SelectSingleNode('InstallFolder').SetAttribute('Path', $InstallFolderPath)
#			}
#			$InputObject.Save((Get-PlConfigurationFile).FullName)
#			if ($PassThru.IsPresent)
#			{
#				Get-PlConfigurationData
#			}
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function Get-PlConfigurationValueCategory
#{
#	[CmdletBinding()]
#	[OutputType([System.Management.Automation.PSCustomObject])]
#	param
#	(
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[string]$Name
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			$categories = (Get-PlConfigurationData).FirstChild | Get-Member -MemberType Property | select name
#			if (-not $categories)
#			{
#				throw 'No categories found'
#			}
#			$categories = $categories.Name
#			if ($PSBoundParameters.ContainsKey('Name'))
#			{
#				$result = $categories | where { $_ -eq $Name }
#			}
#			else
#			{
#				$result = $categories
#			}
#			$result | foreach {
#				[PSCustomObject]@{
#					'Category' = $_
#				}
#			}
#			
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function Get-PlConfigurationValue
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory,ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[object]$InputObject,
#
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Name
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			if (-not (Get-PlConfigurationValueCategory -Name $InputObject.Category))
#			{
#				throw "The category [$($InputObject.Category)] could not be found."
#			}
#			if (-not ($result = $InputObject.FirstChild.($InputObject.Category).GetAttribute($Name)))
#			{
#				throw "No configuration value by the name of [$($Name)] was found."
#			}
#			else
#			{
#				[PSCustomObject]@{
#					'Category' = $InputObject.Category
#					'Name' = $Name
#					'Value' = $result
#				}
#			}
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function New-PlConfigurationValueCategory
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory, ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[System.Xml.XmlDocument]$InputObject,
#		
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Name
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			if ($InputObject.FirstChild.SelectSingleNode($Name))
#			{
#				throw "The configuration category [$($Name)] already exists."
#			}
#			
#			$element = $InputObject.CreateElement($Name)
#			$null = $InputObject.FirstChild.AppendChild($element)
#			
#			$InputObject.Save((Get-PlConfigurationFile).FullName)
#			
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function Remove-PlConfigurationValueCategory
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory, ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[System.Xml.XmlDocument]$InputObject,
#	
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Category,
#	
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[switch]$PassThru
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			if (Get-PlConfigurationValueCategory -Name $Category -InputObject $InputObject)
#			{
#				$null = $InputObject.FirstChild.RemoveChild($InputObject.FirstChild.SelectSingleNode($Category))
#				$InputObject.Save((Get-PlConfigurationFile).FullName)
#			}
#			else
#			{
#				Write-Warning -Message "The category [$($Category)] already doesn't exist"
#			}
#			if ($PassThru.IsPresent)
#			{
#				$InputObject	
#			}
#			
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function New-PlConfigurationValue
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory, ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[System.Xml.XmlDocument]$InputObject,
#	
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Category,
#		
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Name,
#		
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Value,
#	
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[switch]$PassThru
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			if (-not (Get-PlConfigurationValueCategory -InputObject $InputObject -Name $Category))
#			{
#				$categories = Get-PlConfigurationValueCategory -InputObject $InputObject
#				throw "The configuration category [$($Category)] does not exist. Possible values are: [$($categories -join ',')]. To create a new category use New-PlConfigurationCategory"
#			}
#
#			$InputObject.FirstChild.SelectSingleNode($Category).SetAttribute($Name, $Value)
#			
#			$InputObject.Save((Get-PlConfigurationFile).FullName)
#			if ($PassThru.IsPresent)
#			{
#				$InputObject	
#			}
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#
#function Remove-PlConfigurationValue
#{
#	[CmdletBinding()]
#	param
#	(
#		[Parameter(Mandatory, ValueFromPipeline)]
#		[ValidateNotNullOrEmpty()]
#		[System.Xml.XmlDocument]$InputObject,
#	
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Category,
#		
#		[Parameter(Mandatory)]
#		[ValidateNotNullOrEmpty()]
#		[string]$Name,
#	
#		[Parameter()]
#		[ValidateNotNullOrEmpty()]
#		[switch]$PassThru
#		
#	)
#	begin
#	{
#		$ErrorActionPreference = 'Stop'
#	}
#	process
#	{
#		try
#		{
#			if (-not ($InputObject | Get-PlConfigurationValueCategory -Name $Category))
#			{
#				$categories = $InputObject | Get-PlConfigurationValueCategory
#				throw "The configuration category [$($Category)] does not exist. Possible values are: [$($categories -join ',')]. To create a new category use New-PlConfigurationCategory"
#			}
#			
#			$InputObject.FirstChild.$Category.RemoveAttribute($Name)
#			
#			$InputObject.Save((Get-PlConfigurationFile).FullName)
#			if ($PassThru.IsPresent)
#			{
#				$InputObject	
#			}
#		}
#		catch
#		{
#			Write-Error $_.Exception.Message
#		}
#	}
#}
#endregion