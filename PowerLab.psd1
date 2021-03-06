@{
	RootModule = 'PowerLab'

	# Version number of this module.
	ModuleVersion = '1.0.0'

	# ID used to uniquely identify this module
	GUID = '3aad272a-fb09-41a2-8208-f3eaa1c3e7a5'

	# Author of this module
	Author = 'Adam Bertram'

	# Company or vendor of this module
	CompanyName = 'Adam the Automator, LLC'

	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '4.0'

	# Assemblies that must be loaded prior to importing this module
	#RequiredAssemblies = 'Microsoft.SqlServer.SMO'
	
	RequiredModules = 'Hyper-V'
	
	FileList = 'Configuration.xml','Convert-WindowsImage.ps1'
	
	NestedModules = 'PowerLabDatabase.psm1','PowerLabCheckpoint.psm1','PowerLabConfiguration.psm1','PowerLabHostsFile.psm1','PowerLabSwitch.psm1','PowerLabServer.psm1','PowerLabVhd.psm1','PowerLabVM.psm1','PowerLabVMGroup.psm1'
	
	PrivateData = @{
		PSData = @{
			Tags = 'Lab'
			ProjectUri = 'https://github.com/adbertram/PowerLab'
		}
	}
}

