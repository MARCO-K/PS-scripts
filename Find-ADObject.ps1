function Find-ADObject
{
  <#
    .Synopsis
    Resolve Active Directory objects

    .DESCRIPTION
    This function resolves Active Directory objects from a inputlist.

    .Parameter inputfile
    Name of the input file. 
    The input has to be a csv file with ';' as delimiter. The the first column has to be "name".

    .Parameter outputfile
    Name of the output path.

    .Parameter EnumMembers
    Switch to enable recursive enumaration of group members.

    .EXAMPLE
    Find-ADObject -inputfile C:\path\userlist.csv -outputfile C:\path\ -EnumMembers

    .OUTPUTS
    The function will output a object with porperties Name,Exists,DistinguishedName,Enabled,DisplayName,ObjectClass,NestedIn.
    If a outpufile parameter is given the function will write a file to the path.
  #>


  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [ValidateScript({
          if( -Not ($_ | Test-Path) )
          {
            throw 'File or folder does not exist'
          }
          return $true
    })]
    [IO.FileInfo]$inputfile,
    [Parameter()]
    [ValidateScript({
          if( -Not ($_ | Test-Path) )
          {
            throw 'File or folder does not exist'
          }
          return $true
    })]
    [IO.FileInfo]$outputfile,
    [Switch]$EnumMembers

  )

  begin {
    $Coll = Import-Csv -Delimiter ';' -Path $inputfile | Sort-Object -Property name, domain, type -Unique
 
    $Objects = 
    ForEach($obj in $Coll) 
    {
      try 
      {
        $name = $($obj.name)
        Write-Verbose -Message "Resolving $name"
        $ADobject = Get-ADObject -Filter {
          Name -like $name
        } -Property Name, DistinguishedName, ObjectClass | Get-Unique
        New-Object -TypeName psobject -Property ([Ordered]@{
            Name              = $ADobject.Name
            DistinguishedName = $ADobject.DistinguishedName
            ObjectClass       = $ADobject.ObjectClass
        })
      }
      catch 
      {
        Write-Verbose -Message "Couldn't resolve $name"
        New-Object -TypeName psobject -Property ([Ordered]@{
            Name              = $name
            DistinguishedName = ''
            ObjectClass       = $obj.type
        })
      }
    }

  }

  process {

    $Result = 
    foreach($object in $Objects) 
    {
      switch($object.ObjectClass)
      {
        'user'
        {
          try 
          {
            $ADobject = Get-ADUser -Identity $object.DistinguishedName -Properties CN, DistinguishedName, Enabled, DisplayName, ObjectClass
            Write-Verbose -Message "User '$($object.name)' exists in AD."
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $ADobject.CN
                Exists            = $true
                DistinguishedName = $ADobject.DistinguishedName
                Enabled           = $ADobject.Enabled
                DisplayName       = $ADobject.DisplayName
                ObjectClass       = $ADobject.ObjectClass
                NestedIn          = ''
            })
          }
          catch 
          {
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $object.Name
                Exists            = $false
                DistinguishedName = ''
                Enabled           = ''
                DisplayName       = ''
                ObjectClass       = $object.ObjectClass
                NestedIn          = ''
            })
            Write-Verbose -Message "User '$($object.name)' DOES NOT exist in AD."
          }
        }
        'group' 
        {
          try 
          {
            $ADobject = Get-ADGroup -Identity $object.DistinguishedName -Properties CN, DistinguishedName, Enabled, DisplayName, ObjectClass
            Write-Verbose -Message "Group '$($object.name)' exists in AD."
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $ADobject.CN
                Exists            = $true
                DistinguishedName = $ADobject.DistinguishedName
                Enabled           = $ADobject.Enabled
                DisplayName       = $ADobject.DisplayName
                ObjectClass       = $ADobject.ObjectClass
                NestedIn          = ''
            })
          }
          catch 
          {
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $object.Name
                Exists            = $false
                DistinguishedName = ''
                Enabled           = ''
                DisplayName       = ''
                ObjectClass       = $object.ObjectClass
                NestedIn          = ''
            })
            Write-Verbose -Message "Group '$($object.name)' DOES NOT exist in AD."
          }
        }
        'computer'
        {
          try 
          {
            $ADobject = Get-ADComputer -Identity $object.DistinguishedName -Properties CN, DistinguishedName, Enabled, CanonicalName, ObjectClass
            Write-Verbose -Message "Group '$($object.name)' exists in AD."
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $ADobject.CN
                Exists            = $true
                DistinguishedName = $ADobject.DistinguishedName
                Enabled           = $ADobject.Enabled
                DisplayName       = $ADobject.CanonicalName
                ObjectClass       = $ADobject.ObjectClass
                NestedIn          = ''
            })
          }
          catch 
          {
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $object.Name
                Exists            = $false
                DistinguishedName = ''
                Enabled           = ''
                DisplayName       = ''
                ObjectClass       = $object.ObjectClass
                NestedIn          = ''
            })
            Write-Verbose -Message "Group '$($object.name)' DOES NOT exist in AD."
          }
        }
      }
    }

    if($EnumMembers) 
    {
      $groups = $Result | Where-Object -FilterScript {
        $_.ObjectClass -eq 'group'
      }

      $result2 = 
      foreach($group in $groups) 
      {
        $mygroup = Get-ADGroup -Identity $group.Name -Properties Members
    
        foreach ($member in $mygroup.members) 
        {
          $object = $member | Get-ADObject -Properties  CN, DistinguishedName, Enabled, DisplayName, ObjectClass
          if ($object.ObjectClass -eq 'group') 
          {
            Write-Verbose -Message "Found nested group $($object.Name) in $mygroup.Name"
            #recursively run this command for the nested group
            $members = $object |
            Get-ADObject |
            Get-ADGroupMember -Recursive |
            Select-Object -ExpandProperty SamAccountName
            foreach($member in $members) 
            {
              $ADobject = Get-ADUser -Identity $member.SamAccountName -Properties CN, DistinguishedName, Enabled, DisplayName, ObjectClass
              Write-Verbose -Message "User '$($ADobject.CN)' exists in AD."
              New-Object -TypeName psobject -Property ([Ordered]@{
                  Name              = $ADobject.CN
                  Exists            = $true
                  DistinguishedName = $ADobject.DistinguishedName
                  Enabled           = $ADobject.Enabled
                  DisplayName       = $ADobject.DisplayName
                  ObjectClass       = $ADobject.ObjectClass
                  NestedIn          = $mygroup.Name
              })
            }
          } 
          else 
          {
            $ADobject = $object | Select-Object -Property CN, DistinguishedName, DisplayName, ObjectClass
            New-Object -TypeName psobject -Property ([Ordered]@{
                Name              = $ADobject.CN
                Exists            = $true
                DistinguishedName = $ADobject.DistinguishedName
                Enabled           = $ADobject.Enabled
                DisplayName       = $ADobject.DisplayName
                ObjectClass       = $ADobject.ObjectClass
                NestedIn          = $mygroup.Name
            })
          }
        }
      }
      $Result += $result2
    }

  }
  end {
    if ($outputfile) 
    {
      Write-Verbose -Message 'Exporting ADObjects report'
      $Result | Export-Csv -Path (Join-Path -Path ($outputfile) -ChildPath 'result.csv') -Delimiter ';' -NoTypeInformation
    }  

    else
    {
      $Result |
      Sort-Object -Property ObjectClass, Name -Unique |
      Format-Table -AutoSize
    }
  }
}
