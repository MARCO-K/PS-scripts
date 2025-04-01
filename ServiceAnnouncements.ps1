#Requires -Module Microsoft.Graph.Authorization
<#
.SYNOPSIS
Retrieves Microsoft 365 service health information
#>

# --------------------------------------------------
# Initialization
# --------------------------------------------------
$scopes = 'ServiceMessage.Read.All'
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

# Service Messages
$messages = Get-PaginatedResults -Uri "/$apiVersion/admin/serviceAnnouncement/messages"

# Retrieve the serviceAnnouncement messages
$msgList = $messages | ForEach-Object {
    $message = $_
    
    # Create base object
    $msgObject = [pscustomobject]@{
        id                       = $message.id 
        title                    = $message.title
        body                     = $message.body.content
        services                 = $message.services -join ', '
        category                 = $message.category
        isMajorChange            = $message.isMajorChange
        severity                 = $message.severity
        startDateTime            = $message.startDateTime
        endDateTime              = $message.endDateTime
        actionRequiredByDateTime = $message.actionRequiredByDateTime
        lastModifiedDateTime     = $message.lastModifiedDateTime
        hasAttachments           = $message.hasAttachments
        tags                     = if ($message.tags -is [array]) { $message.tags -join ', ' } else { $null }
        viewPoints               = if ($message.viewPoint -is [array]) { $message.viewPoint -join ', ' } else { $message.viewPoint }
    }
    # Add dynamic details as individual properties
    #if ($message.details) {
    #    foreach ($detail in $message.details) {
    #        $propName = $detail.name
    #        $msgObject | Add-Member -MemberType NoteProperty -Name $propName -Value $detail.value
    #   }
    #}

    # Add details as a single string property
    if ($message.details)
    {
        $detailString = ($message.details | ForEach-Object { "$($_.name): $($_.value)" }) -join " | "
        $msgObject | Add-Member -MemberType NoteProperty -Name 'Details' -Value $detailString
    }
    $msgObject
}

# Display the MajorChange messages in a grid view
$msgList | Where-Object { $_.isMajorChange } | Out-GridView -Title "Major Changes"

## Service Issues
## identical to all healthOverviews  details with issues
$issues = Get-PaginatedResults -Uri "/$apiVersion/admin/serviceAnnouncement/issues"

# Create a custom object for each issue
$serviceIssues = $issues | ForEach-Object {
    $issue = $_
    [PSCustomObject]@{
        Id                   = $issue.id
        Service              = $issue.service
        Status               = $issue.status
        StartDateTime        = $issue.startDateTime
        EndDateTime          = $issue.endDateTime
        LastModifiedDateTime = $issue.lastModifiedDateTime
        Title                = $issue.title
        Classification       = $issue.classification
        ImpactDescription    = $issue.impactDescription
        Origin               = $issue.origin
        IsResolved           = $issue.isResolved
        Feature              = $issue.feature
        FeatureGroup         = $issue.featureGroup
        IssueDetails         = if ($issue.details -is [array]) { ($issue.details | ForEach-Object { "$($_.name): $($_.value)" }) -join " | " } else { $null }
    }
} 

# Display open issues messages in a grid view
$serviceIssues | Where-Object { $_.IsResolved -eq $false } | Out-GridView -Title "Active Issues"

## Get serviceUpdateMessage details
$changes = $msgList | Where-Object { $_.category -eq 'planForChange' -and $_.isMajorChange -and $_.tags -like '*Retirement*' } | Select-Object id, title, services, actionRequiredByDateTime, category, tags | Out-GridView -Title "Important Service Updates" -PassThru

if ($changes)
{
    $details = 
    foreach ($change in $changes)
    {
        $Uri = "/$apiVersion/admin/serviceAnnouncement/messages/$($change.id)"
        $changedetail = Invoke-MgGraphRequest -Method GET -Uri $Uri
        $changedetail | ForEach-Object { 
            $change = $_
            [PSCustomObject]@{
                Id                       = $change.id 
                title                    = $change.title
                services                 = $change.services -join ', '
                startDateTime            = $change.startDateTime
                endDateTime              = $change.endDateTime
                actionRequiredByDateTime = $change.actionRequiredByDateTime
                lastModifiedDateTime     = $change.lastModifiedDateTime
                Details                  = if ($change.details -is [array] -and $change.details) { ($change.details | ForEach-Object { "$($_.name): $($_.value)" }) -join " | " } else { $null }
                body                     = if ($change.body.content -is [string])
                { 
                    $change.body.content -replace '(?i)<p[^>]*>', "`n`n" `
                        -replace '(?i)</p>', '' `
                        -replace '(?i)<br\s*/?>', "`n" `
                        -replace '<[^>]+>', '' `
                        -replace '[ \t]+', ' ' `
                        -replace '(?m)^ +| +$', '' `
                        -replace '\n\s*\n', "`n`n" `
                        -replace '\s+$', ''
                } 
                else { $null }
            }
        }
    }
    $details
}