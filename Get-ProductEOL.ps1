<#
.SYNOPSIS
Retrieves product end-of-life information from endoflife.date API

.DESCRIPTION
Gets product lifecycle data either for specified products or all available products

.PARAMETER AllProducts
Retrieve data for all available products

.PARAMETER Product
Specify one or more product names to query

.EXAMPLE
Get-ProductEOL -AllProducts

.EXAMPLE
Get-ProductEOL -Product "windows10", "ubuntu"
#>
function Get-ProductEOL
{
    [CmdletBinding(DefaultParameterSetName = 'AllProducts')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'AllProducts')]
        [switch]$AllProducts,

        [Parameter(
            Mandatory = $true, 
            ParameterSetName = 'Product',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Product
    )

    begin
    {
        $baseUri = "https://endoflife.date/api"

        function Convert-ApiDate
        {
            param([string]$DateString)
            $parsedDate = [Datetime]::MinValue
            if ([datetime]::TryParseExact(
                    $DateString, 
                    'yyyy-MM-dd', 
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::None, 
                    [ref]$parsedDate
                ))
            {
                $parsedDate
            }
            else
            {
                $DateString
            }
        }

        function Get-ProductData
        {
            param([string]$ProductName)
            
            try
            {
                $uri = "$baseUri/$([System.Web.HttpUtility]::UrlEncode($ProductName)).json"
                $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop

                # Validate response structure
                if (-not $response -or $response -isnot [array])
                {
                    Write-Warning "Unexpected response format for $ProductName"
                    return
                }

                foreach ($item in $response)
                {
                    [PSCustomObject]@{
                        Product         = $ProductName
                        Cycle           = $item.cycle
                        ReleaseLabel    = $item.releaseLabel
                        ReleaseDate     = Convert-ApiDate -DateString $item.releaseDate
                        EOL             = Convert-ApiDate -DateString $item.eol
                        Latest          = $item.latest
                        LTS             = $item.lts
                        Support         = Convert-ApiDate -DateString $item.support
                        ExtendedSupport = if ($item.extendedSupport -eq $false) { $null } else { Convert-ApiDate -DateString $item.extendedSupport } 
                        Link            = $item.link
                    }
                }
            }
            catch
            {
                $errorParams = @{
                    Exception   = $_.Exception
                    Message     = 'Failed to retrieve product list'
                    ErrorAction = 'Stop'
                }
                Write-Error @errorParams
            }
        }
    }

    process
    {
        try
        {
            if ($PSCmdlet.ParameterSetName -eq 'AllProducts')
            {
                $productList = Invoke-RestMethod -Uri "$baseUri/all.json" -ErrorAction Stop
            }
            else
            {
                $productList = $Product
            }

            $productList | ForEach-Object {
                if ($data = Get-ProductData -ProductName $_)
                {
                    $data
                }
            }
        }
        catch
        {
            $message = 'Failed to retrieve product list: {0}' -f $_.Exception.Message
            Write-Error $message -ErrorAction Stop
        }
    }

    end
    {
        # Output is handled automatically through pipeline
    }
}