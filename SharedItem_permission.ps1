$UserPrincipalName = '' # Replace with the user's UPN or email address

# Check and install Microsoft Graph modules if not present
$modulesToInstall = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Files"
)

foreach ($module in $modulesToInstall)
{
    if (-not (Get-Module -ListAvailable -Name $module))
    {
        Write-Host "Installing $module module..." -ForegroundColor Cyan
        Install-Module -Name $module -Force -Scope CurrentUser
    }
}

# Import the required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Files

# Ensure you're connected to Microsoft Graph
try
{
    Connect-MgGraph -Scopes "Files.Read.All", "User.Read.All"
}
catch
{
    Write-Error "Failed to connect to Microsoft Graph. Please check your credentials."
    exit
}

$user = Get-MgUser -UserId $UserPrincipalName -Select Id

# Get Shared Items (using beta API)
$sharedItems = @()
$uri = "https://graph.microsoft.com/beta/users/$($user.Id)/drive"
$response = Invoke-MgGraphRequest -Method Get -Uri $uri


$uri = "https://graph.microsoft.com/beta/drives/$($response.id)/root/children"
$items = Invoke-MgGraphRequest -Method Get -Uri $uri 
$sharedItems = $items.value | Where-Object { $_.Shared -ne $null }
$sharedItems = $sharedItems | ForEach-Object {
    $item = $_
    [pscustomobject] @{
        Id                   = $item.Id
        createdDateTime      = $item.createdDateTime
        lastModifiedDateTime = $item.lastModifiedDateTime
        sharedScope          = $item.shared.scope
        shareType            = if ($item.file) { "File" } else { "Folder" }
        Name                 = $item.Name
        mimeType             = $item.file.mimeType
        sharedLink           = $item.webUrl
    }
}


$sharedItemDetails = $sharedItems | ForEach-Object {
    $item = $_
    $permissionsUri = "https://graph.microsoft.com/beta/drives/$($response.id)/items/$($item.id)/permissions"
    
    try
    {
        $permissions = Invoke-MgGraphRequest -Method Get -Uri $permissionsUri
        
        $sharingDetails = $permissions.value | ForEach-Object {
            [pscustomobject] @{
                Name         = $item.Name
                ItemId       = $item.Id
                CreatedDate  = $item.createdDateTime
                LastModified = $item.lastModifiedDateTime
                SharedLink   = $item.sharedLink
                mimeType     = $item.mimeType
                PermissionId = $_.id
                ShareType    = $item.shareType
                SharedWith   = if ($_.grantedTo)
                {
                    $_.grantedTo.user | ForEach-Object { $_.displayName } 
                }
                else
                { 
                    "Unknown" 
                }
                SharedEmail  = if ($_.grantedTo)
                {
                    $_.grantedTo.user | ForEach-Object { $_.email }
                }
                else
                { 
                    "N/A" 
                }
                Role         = $_.roles -join ', '
            }
        }
        
        $sharingDetails
    }
    catch
    {
        Write-Warning "Could not retrieve permissions for $($item.Name): $_"
    }
}

# Output the results
$sharedItemDetails | ogv