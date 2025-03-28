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
            $format = "yyyy-MM-dd"
            $parsedDate = [DateTime]::MinValue
            [System.Globalization.CultureInfo]$provider = [System.Globalization.CultureInfo]::InvariantCulture
            $style = [System.Globalization.DateTimeStyles]::None
            if ([datetime]::TryParseExact($DateString, $format, $provider, $style, [ref]$parsedDate))
            {
                return $parsedDate
            }
            else
            {
                Write-Warning "Failed to parse date: $DateString"
                $DateString
            }
        }

        function Get-ProductData
        {
            param([string]$ProductName)
            
            try
            {
                Write-Verbose "Fetching data for $ProductName"
                $uri = "$baseUri/$([System.Web.HttpUtility]::UrlEncode($ProductName)).json"
                Write-Verbose "Requesting URI: $uri"
                $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop

                if (-not $response -or $response -isnot [array])
                {
                    Write-Warning "Unexpected response format for $ProductName"
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
                        Support         = $item.support
                        ExtendedSupport = $item.extendedSupport
                        Link            = $item.link
                    }
                }
            }
            catch
            {
                # Fixed error parameters
                $errorParams = @{
                    Exception    = $_.Exception
                    TargetObject = $ProductName
                    Message      = "Failed to retrieve data for $ProductName"
                    ErrorAction  = 'Continue'
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
                if (Get-ProductData -ProductName $_)
                {
                    $data
                }
            }
        }
        catch
        {
            # Proper error handling for main process
            $errorParams = @{
                Exception   = $_.Exception
                Message     = 'Failed to retrieve product list'
                ErrorAction = 'Stop'
            }
            Write-Error @errorParams
        }
    }

    end
    {
        # Output handled through pipeline
    }
}