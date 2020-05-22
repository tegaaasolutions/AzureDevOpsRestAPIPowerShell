function GetUrl() {
    param(
        [string]$orgUrl, 
        [hashtable]$header, 
        [string]$AreaId
    )

    # Area ids
    # https://docs.microsoft.com/en-us/azure/devops/extend/develop/work-with-urls?view=azure-devops&tabs=http&viewFallbackFrom=vsts#resource-area-ids-reference
    # Build the URL for calling the org-level Resource Areas REST API for the RM APIs
    $orgResourceAreasUrl = [string]::Format("{0}/_apis/resourceAreas/{1}?api-preview=5.0-preview.1", $orgUrl, $AreaId)

    # Do a GET on this URL (this returns an object with a "locationUrl" field)
    $results = Invoke-RestMethod -Uri $orgResourceAreasUrl -Headers $header

    # The "locationUrl" field reflects the correct base URL for RM REST API calls
    if ("null" -eq $results) {
        $areaUrl = $orgUrl
    }
    else {
        $areaUrl = $results.locationUrl
    }

    return $areaUrl
}

$orgUrl = "https://dev.azure.com/<Your Organization>"
$personalToken = "<Your PAT>"

Write-Host "Initialize authentication context" -ForegroundColor Yellow
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($personalToken)"))
$header = @{authorization = "Basic $token"}

# DEMO 1 List of projects
Write-Host "Demo 1"
$coreAreaId = "79134c72-4a58-4b42-976c-04e7115f32bf"
$tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId

# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
$projectsUrl = "$($tfsBaseUrl)_apis/projects?api-version=5.1"

$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header

$projects.value | ForEach-Object {
    Write-Host $_.name
}

# DEMO 2 List of release definitions
Write-Host "Demo 2"
$projects.value | ForEach-Object {
    $project = $_.name
    $releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5"
    $tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
    $relDefUrl = "$tfsBaseUrl/$project/_apis/release/definitions?api-version=5.1"
    $result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header
    $relDefs = $result.value
    
    if($relDefs.count -gt 0){
        Write-Host "$project $($relDefs.count) release def founds" -ForegroundColor Blue
        $relDefs | ForEach-Object {
            Write-host "`t$($_.name)" -ForegroundColor Green
        }
    }
}

# DEMO 3 List of releases for a given release definition
Write-Host "Demo 3"
$projects.value | ForEach-Object {
    $project = $_.name
    $releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5"
    $tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
    $relDefUrl = "$tfsBaseUrl/$project/_apis/release/definitions?api-version=5.1"
    $result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header
    $relDefs = $result.value
    
    if($relDefs.count -gt 0){
        Write-Host "$project $($relDefs.count) release def founds" -ForegroundColor Blue
        $relDefs | ForEach-Object {
            $relDefId = $_.id
            Write-host "`t$($_.name)" -ForegroundColor Green

            # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/releases/list?view=azure-devops-rest-5.1
            $relsUrl = "$tfsBaseUrl/$project/_apis/release/releases?definitionId=$relDefId&releaseCount=5&api-version=5.1"
            $result = Invoke-RestMethod $relsUrl -Method Get -ContentType "application/json" -Headers $header
            $rels = $result.releases
            
            if($rels.count -gt 0){
                Write-Host "`t`t$($rels.count) releases found" -ForegroundColor Blue
                $rels | ForEach-Object {
                    $rel = $_
                    Write-Host "`t`t`t$($rel.name)"
                }
            }
        }
    }
}

# DEMO 4 List of approvers for a release environment 
Write-Host "Demo 4"
$projects.value | ForEach-Object {
    $project = $_.name
    $releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5"
    $tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
    $relDefUrl = "$tfsBaseUrl/$project/_apis/release/definitions?api-version=5.1"
    $result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header
    $relDefs = $result.value
    
    if($relDefs.count -gt 0){
        Write-Host "$project $($relDefs.count) release def founds" -ForegroundColor Blue
        $relDefs | ForEach-Object {
            $relDefId = $_.id
            Write-host "`t$($_.name)" -ForegroundColor Green

            # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/releases/list?view=azure-devops-rest-5.1
            $relsUrl = "$tfsBaseUrl/$project/_apis/release/releases?definitionId=$relDefId&releaseCount=5&api-version=5.1"
            $result = Invoke-RestMethod $relsUrl -Method Get -ContentType "application/json" -Headers $header
            $rels = $result.releases
            
            if($rels.count -gt 0){
                Write-Host "`t`t$($rels.count) releases found" -ForegroundColor Blue
                $rels | ForEach-Object {
                    $rel = $_
                    $rel.Environments | ForEach-Object {
                        $envName = $_.name
                        #Write-Host "        $envName" -ForegroundColor Green
                        $env = $_
                        $env.preDeployApprovals | ForEach-Object {
                            $approval = $_
                            if (-not $approval.isAutomated -and $approval.status -eq "approved") {
                                Write-host "`t`t`tRelease $($rel.name) ($envName) was approved By $($approval.approvedBy.displayName) on $($approval.modifiedOn)" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
        }
    }
}

# DEMO 5 Update an environement release variable
Write-Host "Demo 5"
$projects.value | ForEach-Object {
    $project = $_.name
    $releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5"
    $tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
    $relDefUrl = "$tfsBaseUrl/$project/_apis/release/definitions?api-version=5.1"
    $result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header
    $relDefs = $result.value
    
    if($relDefs.count -gt 0){
        Write-Host "$project $($relDefs.count) release def founds" -ForegroundColor Blue
        $relDefs | ForEach-Object {
            $relDef = $_
            # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/get?view=azure-devops-rest-5.1
            $relDefExpanded = Invoke-RestMethod "$($relDef.url)?`$Expand=Environments&api-version=5.1" -Method Get -ContentType "application/json" -Headers $header
            $relDefExpanded.environments | ForEach-Object {
                $env = $_
                if ($null -ne $env.variables.DEMO) {
                    Write-host "Variable value before: $($env.variables.DEMO.value)" -ForegroundColor Green
                    $env.variables.DEMO.value = "New Value"
                }
                $body = $relDefExpanded | ConvertTo-Json -Depth 100 -Compress
                $body = [System.Text.Encoding]::UTF8.GetBytes($body)
                # https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/update?view=azure-devops-rest-5.1
                $updateResult = Invoke-RestMethod "$($relDef.url)?api-version=5.1" -Method Put -ContentType "application/json" -body $body -Headers $header 
                Write-host "Variable value after: $($updateResult.environments.variables.DEMO.value)" -ForegroundColor Green
            }
        }
    }
}


# DEMO 6 Update a work item title
Write-Host "Demo 6"
$workAreaId = "1d4f49f9-02b9-4e26-b826-2cdb6195f2a9"
$tfsBaseUrl = GetUrl -orgUrl $orgUrl -header $header -AreaId $workAreaId

$workItemId = 1
# https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/get%20work%20item?view=azure-devops-rest-5.1
$wisUrl = "$($tfsBaseUrl)/Demos/_apis/wit/workitems/$($workItemId)?api-version=5.1"

$workitem = Invoke-RestMethod -Uri $wisUrl -Method Get -ContentType "application/json" -Headers $header
Write-Host "Before: $($workitem.fields.'System.Title')"

$body = @"
[
  {
    "op": "add",
    "path": "/fields/System.Title",
    "value": "$($workitem.fields.'System.Title')+DEMO"
  },
  {
    "op": "add",
    "path": "/fields/System.History",
    "value": "Changing Title"
  }
]
"@

$workitem = Invoke-RestMethod -Uri $wisUrl -Method Patch -ContentType "application/json-patch+json" -Headers $header -Body $body
Write-Host "After: $($workitem.fields.'System.Title')"
