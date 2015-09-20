#Requires -Version 4

[CmdletBinding()]
param (
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ Test-Path -Path $_ -PathType Container })]
	[string]$ModulesPath = "$PSScriptRoot\PowerLab"	
)

try {

	$commonParams = @{
		'Verbose' = $VerbosePreference
	}
	
	#region Configuration file setup
	$ConfigFilePath = "$ModulesPath\configuration.xml"
	if (-not (Test-Path @commonParams -Path $ConfigFilePath -PathType Leaf))
	{
		$xConfiguration = New-PlConfigurationFile @commonParams -FilePath $ConfigFilePath -PassThru
		New-PlConfigurationValueCategory @commonParams -Name 'Configuration' -InputObject $xConfiguration
	}
	else
	{
		##TODO: Validate XML against XSD
		Write-Verbose -Message 'Existing configuration file found. Using that one.'
	}
	#endregion
	
	#region Install new modules
	$userModulePath = $env:PSModulePath.Split(';') | where { $PSItem -like "*$env:HOMEPATH*" }
	Copy-Item @commonParams -Path $ModulesPath -Destination $userModulePath -Recurse -Force
	#endregion
	
	Import-Module PowerLab
}
catch
{
	Write-Error  "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
}