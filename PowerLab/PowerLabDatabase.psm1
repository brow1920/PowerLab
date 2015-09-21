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
			if (Test-PlDatabase -Database $Database -Instance $Instance)
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
						$col.Nullable = $false
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

function Update-PlDatabaseRow
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
			Invoke-Sqlcmd -Query "SELECT GETDATE() AS TimeOfQuery;" -ServerInstance "MyComputer\MyInstance"
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}