$scopes = 'ServiceHealth.Read.All'
Connect-MgGraph -Scopes $scopes

## List healthOverviews
$uri = "/beta/admin/serviceAnnouncement/healthOverviews"
$messages = Invoke-MgGraphRequest -Method GET -Uri $uri

$healthStatus = $messages.value | ForEach-Object {
    [PSCustomObject]@{
        Id      = $_.id
        Service = $_.service
        Status  = $_.status
    }
}

# Display results
$healthStatus

# collect all healthOverviews  details with issues
$healthcheck = $healthStatus | Where-Object { $_.Status -ne 'serviceOperational' }

$serviceIssues = foreach ($service in $healthcheck)
{
    $filter = "?`$expand=issues"
    $uri = "/beta/admin/serviceAnnouncement/healthOverviews/$($service.Service)$filter"
    $details = Invoke-MgGraphRequest -Method GET -Uri $uri
    $details.issues | ForEach-Object {
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
            details              = if ($issue.details -is [array])
            {
                $issue.details -join ', '
            }
            else
            {
                $issue.details
            }
        }
    }
}

# open issues in a grid view
$serviceIssues | Where-Object { $_.isResolved -eq $false } | ogv