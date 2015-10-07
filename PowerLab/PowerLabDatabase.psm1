$global:Database = (Get-PlConfigurationData).Configuration.Database.Name
$global:Instance = (Get-PlConfigurationData).Configuration.Database.Instance.Name

#Requires -Module sqlps

function Add-PlVmDatabaseEntry
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[datetime]$CreationDate,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$OperatingSystem,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$VMGroup = 'Default',
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$LastAction = 'New VM'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$cols = 'Name', 'VMGroup', 'CreationDate', 'LastAction'
			$vals = $Name, $VMGroup, $CreationDate, $LastAction
			if ($PSBoundParameters.ContainsKey('OperatingSystem')) {
				$cols += 'OperatingSystem'
				$vals += $OperatingSystem
			}
			$params = @{
				'Column' = $cols
				'Value' = $vals
			}
			New-PlDatabaseRow @params
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVMDatabaseEntry
{
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			if ($PSBoundParameters.ContainsKey('Name')) {
				Get-PlDatabaseRow -Table 'VMs' -Column 'Name' -Value $Name
			}
			else
			{
				Get-PlDatabaseRow -Table 'VMs'
			}
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Get-PlVMDatabaseEntry
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
				Get-PlDatabaseRow -Table 'VMs' -Column 'Name' -Value $Name
			}
			else
			{
				Get-PlDatabaseRow -Table 'VMs'
				
				
				
				
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
		[string]$Instance = $Instance,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = $Database,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[System.Xml.XmlElement[]]$Table = (Get-PlDefaultDatabaseConfig).Tables.Table	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if (Test-PlDatabase -Name $Name)
			{
				throw "The database [$($Name)] already exists"
			}

			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
			$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ".\$Instance"
			$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($server, $Name)
			Write-Verbose -Message "Creating the database [$($Name)] in instance [$($Instance)]"
			$db.Create()
			
			$typeConversions = @{
				'int' = [Microsoft.SqlServer.Management.Smo.Datatype]::Int
				'varchar100' = [Microsoft.SqlServer.Management.Smo.Datatype]::NVarChar(100)
				'datetime' = [Microsoft.SqlServer.Management.Smo.Datatype]::DateTime
			}
			
			foreach ($t in $Table)
			{
				Write-Verbose -Message "Creating table [$($t.Name)] in database [$($Name)]"
				$tbl = New-Object ('Microsoft.SqlServer.Management.Smo.Table') ($db, $t.Name, 'dbo')
				$t.Columns.Column | foreach {
					Write-Verbose -Message "Adding column [$($_.Name)] with type [$($typeConversions[$_.Type])]"
					$col = new-object ('Microsoft.SqlServer.Management.Smo.Column') ($tbl, $_.Name, $typeConversions[$_.Type])
					if ($_.PrimaryKey -eq 'Yes')
					{
						Write-Verbose -Message "The [$($_.Name)] column needs to be the primary key"
						$col.Identity = $true
						$col.IdentitySeed = 1
						$col.IdentityIncrement = 1
					}
					else
					{
						$col.Nullable = $true
					}
					
					$tbl.Columns.Add($col)
				}
				$pk = new-object ('Microsoft.SqlServer.Management.Smo.Index') ($tbl, "PK_$Name")
				$pk.IndexKeyType = 'DriPrimaryKey'
				$pk.IsClustered = $true
				
				$idxColName = ($t.Columns.Column | where { $_.Index -eq 'yes' }).Name
				Write-Verbose -Message "The index column needs to be [$($idxColName)]"
				$indexCol = new-object ('Microsoft.SqlServer.Management.Smo.IndexedColumn') ($pk, $idxColName)
				$pk.IndexedColumns.Add($indexCol)
				$tbl.Indexes.Add($pk)
				
				#Create the table
				$tbl.Create()
			}
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
		[string]$Instance = $Instance,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = $Database
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Write-Verbose -Message "Testing for the presence of the database [$($Name)] in instance [$($Instance)]"
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
			$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ".\$Instance"
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

function Get-PlDatabaseRow
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Table,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Column,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Value
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$sqlParams = @{
				'Database' = $Database
				'ServerInstance' = $Instance
			}
			if ($PSBoundParameters.ContainsKey('Column')) {
				$sqlParams.Query = "SELECT * FROM $Table WHERE $Column = '$Value'"
			}
			else
			{
				$sqlParams.Query = "SELECT * FROM $Table"	
			}
			Invoke-Sqlcmd @sqlParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function New-PlDatabaseRow
{
	[CmdletBinding()]
	param
	(
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Column,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Value,
		
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
			$sqlParams = @{
				'Database' = $Database
				'ServerInstance' = $Instance
				'Query' = "INSERT INTO $Table ($($Column -join ',')) VALUES ('$($Value -join "','")')"
			}
			Invoke-Sqlcmd @sqlParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-PlDatabaseRow
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Table,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Column,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Value
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$sqlParams = @{
				'Database' = $Database
				'ServerInstance' = $Instance
				'Query' = "DELETE FROM $Table WHERE $Column = '$Value'"
			}
			Invoke-Sqlcmd @sqlParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Update-PlDatabaseRow
{
	[CmdletBinding()]
	param
	(
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[int]$VMId,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[hashtable[]]$Row,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Table = 'VMs'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$vmIdColName = ((Get-PlConfigurationData).Configuration.Database.SelectSingleNode("//Table[@Name='$Table']").Columns.Column | where { $_.PrimaryKey -eq 'Yes' }).Name
			
			$keyPairs = @()
			$Row | foreach {
				$_.GetEnumerator() | foreach {
					$keyPairs += "$($_.Key) = '$($_.Value)'"
				}
			}
			
			$sqlParams = @{
				'Database' = $Database
				'ServerInstance' = $Instance
				'Query' = "UPDATE $Table SET $($keyPairs -join ',') WHERE $vmIdColName=$VMId"
			}
			Write-Verbose -Message "UPDATE $Table SET $($keyPairs -join ',') WHERE $vmIdColName=$VMId"
			Invoke-Sqlcmd @sqlParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}