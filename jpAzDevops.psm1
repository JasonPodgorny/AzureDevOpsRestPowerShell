## JP Azure Devops Module - Powershell 4.0 + PowerCLI 5.8 release 1

function Ignore-SSL-Errors {
	### Ignore TLS/SSL errors	
	add-type @"
	    using System.Net;
	    using System.Security.Cryptography.X509Certificates;
	    public class TrustAllCertsPolicy : ICertificatePolicy {
	        public bool CheckValidationResult(
	            ServicePoint srvPoint, X509Certificate certificate,
	            WebRequest request, int certificateProblem) {
	            return true;
	        }
	    }
"@
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

function Connect-JpAzDevOps {
	<#
		.SYNOPSIS
			Connects to a Azure Devops Via REST.
		.DESCRIPTION
			Connects to a Azure Devops Via REST. The cmdlet starts a new session with a Devops Org/Project using the specified parameters.
		.PARAMETER  Hostname
			Specify The Azure Devops Hostname For Your Organization And Project.  Ex: dev.azure.com
		.PARAMETER  Username
			Specify the user name you want to use for authenticating with the server. 
		.PARAMETER  Password
			Specifies the password you want to use for authenticating with the server.
		.EXAMPLE
			PS C:\> Connect-JpNSXManager -server "192.168.0.88" -username "admin" -password "default"
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,
            HelpMessage="Azure DevOps Hostname.   Ex:  dev.azure.com")]
		[string]$Hostname,
		[Parameter(Mandatory=$False,
			HelpMessage="Azure DevOps Organization.")]
		[string]$Organization,
		[Parameter(Mandatory=$True,
			HelpMessage="Azure DevOps Project.")]
		[string]$Project,
		[string]$Username = "JP-AZ-REST",
		[Parameter(Mandatory=$True)]
		[string]$AccessToken
	)
	

	begin {
		Ignore-SSL-Errors	
	}
	
	process {
		if ( $Organization ) {
			$baseProjectUrl = "https://" + "${Hostname}" + "/" + "${Organization}" + "/" + "${Project}" + "/_apis/"
		} else {
			$baseProjectUrl = "https://" + "${Hostname}" + "/" + "${Project}" + "/_apis/"
		}
		Write-Debug "Connecting to Azure Devops at $baseProjectUrl"
		if ($Global:DefaultDevOpsProject) {
			$current_url_name = ($Global:DefaultDevOpsProject.name)
			Write-Warning "Cannot connect - already connected to Azure DevOps Project $current_url_name"
			return		
		}	
		try {	
			$connection_ok = $true
			#Building the headers
			$auth = $Username + ':' + $AccessToken
			$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
			$EncodedPassword = [System.Convert]::ToBase64String($Encoded)
			$headers = @{"Authorization"="Basic $($EncodedPassword)";}
			$session = Invoke-RestMethod -Headers $headers -Uri $baseProjectUrl -Method Get -ContentType Application/json -Timeout 10
		} catch {
			Write-Warning "Failed to connect to Azure DevOps Project:  $baseProjectUrl"
			Write-Debug "$_"
			$connection_ok = $false
		}
		if ($connection_ok) {
			Write-Debug "Successfully connected to Azure DevOps Project at $baseProjectUrl"					
			$obj = New-Object -TypeName PSObject -Property @{
				Hostname = $Hostname
				Organization = $Organization
				Project = $Project
				ServerUri = $baseProjectUrl
				Authorization = $headers
			}	
			$Global:DefaultDevOpsProject = $obj
			Write-Output $obj
		}
	}	
}

function Disconnect-JpAzDevOps {
	<#
		.SYNOPSIS
			Disconnects Azure Devops REST Session.
		.DESCRIPTION
			Disconnects Azure Devops REST Session.  The cmdlet stops a session with an Azure DevOps Project.
		.EXAMPLE
			PS C:\> Disconnect-JpAzDevOps 
	#>
	[CmdletBinding()]
	Param ()
	
	begin {}
	
	process {
		
		if ($Global:DefaultDevOpsProject) {
			$current_url_name = ($Global:DefaultDevOpsProject.name)
			Write-Debug "Disconnecting from Azure DevOps Project: $current_url_name"
			$Global:DefaultDevOpsProject = $null
			return		
		} else { 
			Write-Warning "Not connected to a DevOps Project"
		}
	
	}
	
}

#Declare the GET function
Function Calling-Get {
	[CmdletBinding()]
	param (
		$Url
	)
	begin {
		Ignore-SSL-Errors	
	}
	process {	
		Write-Debug "Invoking REST GET at URL $url"	
		if ( !$Global:DefaultDevOpsProject ) {		
			Write-Warning "Must connect to Azure DevOps Project before attempting GET"
			return
		}	
		try {
			$headers = ($Global:DefaultDevOpsProject.Authorization)		
			Invoke-RestMethod -Headers $headers -Uri $url -Method Get -ContentType Application/json
		} catch { 
			Write-Warning "$_"
			Write-Warning "Get Failed at - $url"
		}		
	
	}
}

Function Calling-Put {
	[CmdletBinding()]
	param (
		$Url,
		$Body
	)
	begin {	
		Ignore-SSL-Errors
	}
	process { 
		Write-Debug "Invoking REST PUT at URL $url"	
		if ( !$Global:DefaultDevOpsProject ) {
			Write-Warning "Must connect to Azure DevOps Project before attempting PUT"
			return
		}
		try {
		    $headers = ($Global:DefaultDevOpsProject.Authorization)	

			Invoke-RestMethod -Headers $headers -Uri $url -Body $Body -Method Put -ContentType Application/json 
		} catch { 
			Write-Warning "$_"
			Write-Warning "Put Failed at - $url"
		}
	}
}

#Declare the POST function
Function Calling-Post {
	[CmdletBinding()]
	param (
		$Url,
		$Body
	)
	begin {
		Ignore-SSL-Errors	
	}
	process {
		Write-Debug "Invoking REST POST at URL $url"	
		if ( !$Global:DefaultDevOpsProject ) {
			Write-Warning "Must connect to Azure DevOps Project before attempting POST"
			return
		}
		try {
		    $headers = ($Global:DefaultDevOpsProject.Authorization)
			Invoke-RestMethod -Headers $headers -Uri $url -Body $Body -Method Post -ContentType Application/json -TimeOutSec 300
		} catch { 
			Write-Warning "$_" 
			Write-Warning "Post Failed at - $url"
		}
	}
}

#Declare the DELETE function
Function Calling-Delete {
	[CmdletBinding()]
	param (
		$Url
	)
	begin {
		Ignore-SSL-Errors	
	}
	process {	
		Write-Debug "Invoking REST DELETE at URL $url"	
		if ( !$Global:DefaultDevOpsProject ) {		
			Write-Warning "Must connect to Azure DevOps Project before attempting DELETE"
			return
		}	
		try {
			$headers = ($Global:DefaultDevOpsProject.Authorization)		
			Invoke-RestMethod -Headers $headers -Uri $url -Method Delete -ContentType Application/json 
		} catch { 
			Write-Warning "$_"
			Write-Warning "Delete Failed at - $url"
		}		
	
	}
}

function Get-JpAzDevopsRepos {
	<#
		.SYNOPSIS
			Gets List Of Repositories From Azure Devops Project
		.DESCRIPTION
			Gets List Of Repositories From Azure Devops Project
		.PARAMETER  Name
			Azure Devops Repo Name(s) to list.  Lists all repos if left blank
		.EXAMPLE
			PS C:\> Get-JpAzDevopsRepos
		.EXAMPLE
			PS C:\> Get-JpAzDevopsRepos -name repo1,repo2
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$True,
            HelpMessage="DevOps Repo Names")]
		[string[]]$Name
	)
	
	begin {} 
	
	process { 
		Write-Debug "Getting Devops Repoitories"
		$url = "$($Global:DefaultDevOpsProject.ServerURI)git/repositories?api-version=6.0"
		$repoList = Calling-Get -url $url
		foreach ($repo in $repoList.value) {
			$obj = New-Object -type PSObject -Property @{
				"name" = $repo.name
				"id" = $repo.id
				"defaultBranch" = $repo.defaultBranch
				"size" = $repo.size
				"url" = $repo.webUrl
				"disabled" = $repo.isDisabled
			}
			if ( $name ) { 
				foreach ( $repoName in $name ) {
					if ($obj.name -eq $repoName) {
						write-output $obj
					}
				}
			} else {
				write-output $obj
			}
		}
	}
	
}

function Get-JpAzDevopsPipelines {
	<#
		.SYNOPSIS
			Gets List Of Pipelines From Azure Devops Project
		.DESCRIPTION
			Gets List Of Pipelines From Azure Devops Project
		.PARAMETER  Name
			Azure Devops Pipelines Name(s) to list.  Lists all Pipelines if left blank
		.EXAMPLE
			PS C:\> Get-JpAzDevopsPipelines
		.EXAMPLE
			PS C:\> Get-JpAzDevopsPipelines -name pipeline1,pipeline2
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$True,
            HelpMessage="DevOps Pipelines Names")]
		[string[]]$Name
	)
	
	begin {} 
	
	process { 
		Write-Debug "Getting Devops Pipelines"
		$url = "$($Global:DefaultDevOpsProject.ServerURI)pipelines?api-version=6.0-preview.1"
		$pipelineList = Calling-Get -url $url
		foreach ($pipeline in $pipelineList.value) {
			$obj = New-Object -type PSObject -Property @{
				"name" = $pipeline.name
				"id" = $pipeline.id
				"revision" = $pipeline.revision
				"folder" = $pipeline.folder
				"url" = $pipeline.url
			}
			if ( $name ) { 
				foreach ( $pipelineName in $name ) {
					if ($obj.name -eq $pipelineName) {
						write-output $obj
					}
				}
			} else {
				write-output $obj
			}
		}
	}
	
}

function Get-JpAzDevopsPipelineRuns {
	<#
		.SYNOPSIS
			Gets List Of Pipeline Runs For Pipeline From Azure Devops Project
		.DESCRIPTION
			Gets List Of Pipeline Runs For Pipeline From Azure Devops Project
		.PARAMETER  Id
			Azure Devops Pipelines Id to list runs for. 
		.EXAMPLE
			PS C:\> Get-JpAzDevopsPipelineRuns
		.EXAMPLE
			PS C:\> Get-JpAzDevopsPipelineRuns -id 1
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipelineByPropertyName=$True,
            HelpMessage="DevOps Pipeline Id")]
		[string]$id
	)
	
	begin {} 
	
	process { 
		Write-Debug "Getting Devops Pipeline Runs"
		$url = "$($Global:DefaultDevOpsProject.ServerURI)pipelines/${id}/runs?api-version=6.0-preview.1"
		$pipelineRunList = Calling-Get -url $url
		foreach ($pipelineRun in $pipelineRunList.value) {
			$obj = New-Object -type PSObject -Property @{
				"name" = $pipelineRun.name
				"id" = $pipelineRun.id
				"state" = $pipelineRun.state
				"result" = $pipelineRun.result
				"createdDate" = $pipelineRun.createdDate
				"finishedDate" = $pipelineRun.finishedDate
			}
			write-output $obj
		}
	}
	
}

export-modulemember -Function Connect-JpAzDevOps
export-modulemember -Function Disconnect-JpAzDevOps
export-modulemember -Function Get-JpAzDevopsRepos
export-modulemember -Function Get-JpAzDevopsPipelines
export-modulemember -Function Get-JpAzDevopsPipelineRuns