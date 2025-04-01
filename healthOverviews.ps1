#Requires -Module Microsoft.Graph.Authorization
<#
.SYNOPSIS
Retrieves Microsoft 365 service health information
#>

# --------------------------------------------------
# Initialization
# --------------------------------------------------

$scopes = 'ServiceHealth.Read.All'
$apiVersion = "beta"  # Consider "v1.0" when available


try
{
    Connect-MgGraph -Scopes $scopes
}
catch
{
    Write-Error "Failed to connect to Microsoft Graph: $_"
}

# --------------------------------------------------
# Functions
# --------------------------------------------------
function Get-PaginatedResults
{
    param($Uri)
    $results = @()
    do
    {
        try
        {
            $response = Invoke-MgGraphRequest -Method GET -Uri $Uri
            $results += $response.value
            $Uri = $response.'@odata.nextLink'
        }
        catch
        {
            Write-Error "API request failed for URI '$Uri': $_"
            return $null
        }
    } while ($Uri)
    $results
}

## List healthOverviews
$serviceAnnouncements = Get-PaginatedResults -Uri "/$apiVersion/admin/serviceAnnouncement/healthOverviews"

$healthStatus = $serviceAnnouncements | ForEach-Object {
    [PSCustomObject]@{
        Id      = $_.id
        Service = $_.service
        Status  = $_.status
    }
}

# Display results
$healthStatus | Out-GridView -Title "Service Health Overview"

# collect all healthOverviews  details with issues
$healthcheck = $healthStatus | Where-Object { $_.Status -ne 'serviceOperational' }

$serviceIssues = foreach ($service in $healthcheck)
{
    $filter = "?`$expand=issues"
    $issues = (Invoke-MgGraphRequest -Method GET -Uri "/$apiVersion/admin/serviceAnnouncement/healthOverviews/$($service.Service)$filter").issues
    $issues | ForEach-Object {
        $issue = $_    
        [PSCustomObject]@{
            ServiceId            = $service.id
            Service              = $service.service
            Status               = $service.status
            IssueId              = $issue.id
            IssueStatus          = $issue.status
            startDateTime        = $issue.startDateTime
            endDateTime          = $issue.endDateTime
            lastModifiedDateTime = $issue.lastModifiedDateTime
            title                = $issue.title
            classification       = $issue.classification
            impactDescription    = $issue.impactDescription
            origin               = $issue.origin
            isResolved           = $issue.isResolved
            feature              = $issue.feature
            featureGroup         = $issue.featureGroup
            IssueServices        = $issue.service
            Details              = if ($issue.details -is [array] -and $issue.details) { ($issue.details | ForEach-Object { "$($_.name): $($_.value)" }) -join " | " } else { $null }
        }
    }
}

# open issues in a grid view
$serviceIssues | Where-Object { -not $_.IsResolved } | Out-GridView -Title "Active Service Issues"