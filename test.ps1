Install-Module Az
Install-Module -Name MSAL.PS

Connect-AzAccount

$ResourceGroupName = "RG01"
$Region = "EastUS"

$rg = get-AzResourceGroup -Name $ResourceGroupName


$VaultName = "MME-AKV-PS" 

$kv =  New-AzKeyVault -Name $VaultName -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -Verbose

$SecretName = "MME-PS-Key3" 
$SecretValue = "jMb8Q~-deGFs1dLeZRZmujl89Z7VdjkgxNHZ7aXa" 

#Add Secret to key vault 
$Secretvalue = ConvertTo-SecureString $SecretValue -AsPlainText -Force 
$SetSecret = Set-AzKeyVaultSecret -VaultName $kv.VaultName -Name $SecretName -SecretValue $secretvalue 


### using the secret
$SecretValue = ""

#Return connection secret to ConnectionSecrets variable
$ConnectionSecrets = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name $SecretName
$SecretValue = $ConnectionSecrets.SecretValue



#Authenticate to Azure with app registration and return authorization token.
$authparams = @{ 

    ClientId    = '6c5ac38e-8ddc-4a13-953f-726beb2f676d' 
    TenantId    = '775fb56c-2847-4743-b9ff-51ffa2be3a64' 
    ClientSecret = $SecretValue

} 

$auth = Get-MsalToken @authParams
$auth 