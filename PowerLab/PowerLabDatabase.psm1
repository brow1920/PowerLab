$global:Database = (Get-PlConfigurationData).Configuration.Database.Name
$global:Instance = (Get-PlConfigurationData).Configuration.Database.Instance.Name

function New-PlDatabase
{
	[CmdletBinding()]
	param
	(
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
			if (Test-PlDatabase)
			{
				throw "The database [$($Database)] already exists"
			}
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
			$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $Instance
			$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database($server, $Database)
			$db.Create()
			
			$typeConversions = @{
				'int' = [Microsoft.SqlServer.Management.Smo.Datatype]::Int
				'varchar100' = [Microsoft.SqlServer.Management.Smo.Datatype]::NVarChar(100)
				'datetime' = [Microsoft.SqlServer.Management.Smo.Datatype]::DateTime
			}
			
			foreach ($t in $Table)
			{
				Write-Verbose -Message "Creating table [$($t.Name)] in database [$($Database)]"
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
				$pk = new-object ('Microsoft.SqlServer.Management.Smo.Index') ($tbl, "PK_$Database")
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
	()
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
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Column,
		
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
			}
			if ($PSBoundParameters.ContainsKey('Column')) {
				$sqlParams.Query = "SELECT $($Column -join ',') FROM $Table"
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
		[string]$Column,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		
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
			$sqlParams = @{
				'Database' = $Database
				'ServerInstance' = $Instance
				'Query' = "UPDATE $Table SET $Column='$Value' WHERE $vmIdColName=$VMId"
			}
			Invoke-Sqlcmd @sqlParams
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}