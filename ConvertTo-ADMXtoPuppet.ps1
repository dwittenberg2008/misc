#requires -version 4.0
#requires -Module GroupPolicy

<#
.Synopsis
   ConvertTo-ADMXtoPuppet allows you to get registry keys and values configured within the registry.pol file in existing GPOs
   and use that information to create DSC docuemnts.
.DESCRIPTION
   Group Policy Objects have been created, managed, configured, re-configured, deleted,
   backed up, imported, exported, inspected, detected, neglected and rejected for many years. 
   Now with the advent of Desired State Configuration (DSC) ensuring that the work previously 
   done with regards to configuring registry policy is not lost, is key. ConvertTo-ADMXtoPuppet is a cmdlet 
   (advanced function) that was created to address this sceanario. The ConvertTo-ADMXtoPuppet cmdlet
   requires the GroupPolicy PowerShell Module. The GP cmdlets are avaialbe on machines where 
   the GPMC is installed. The <gponame>.ps1 file will be opened in the PowerShell ISE as a
   convenience.
.EXAMPLE
   ConvertTo-ADMXtoPuppet -GPOName <gpo> -OutputFolder <folder where to create DSC .ps1 file>
.EXAMPLE
   GP2DSC -GPOName <GPO> -OutputFolder <folder>

   Get-GPO -all | % { ConvertTo-AdMXtoPuppet -gpoName "$($_.DisplayName)" -outputFolder c:\temp }

.LINK
    Http://www.github.com/gpoguy
#>

function ConvertTo-ADMXtoPuppet
{
    # add additional cmdletBinding information to make the experience more robust.
    [CmdletBinding()]
    [Alias("GP2DSC")]
    [OutputType([int])]
    # possible new scenarios... optional open in ISE when complete. 
    # optional create of .mof file, including target test machine. This scenario would 
    # be an e2e test where the GPO is selected, Registry data is converted to .ps1 config
    # the configuration is called and .mof is created and DSC configuration is started targeting
    # a test machine.
    Param
    # possibly re-work parameter names.
        ([Parameter(Mandatory=$true)]
        [string]$gpoName,
        [Parameter(Mandatory=$true)]
        [Alias("Path")]
        [string] $outputFolder
    )

    Begin 
    {
        Write-Verbose "Starting: $($MyInvocation.Mycommand)"  
        #display PSBoundparameters formatted nicely for Verbose output  
        [string]$pb = ($PSBoundParameters | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Verbose "PSBoundparameters: `n$($pb.split("`n").Foreach({"$("`t"*4)$_"}) | Out-String) `n" 

         function ADMtoDSC
        {
            [cmdletbinding()]
            param
            ( 
               [String] $gpo,
               [String] $path
            )

            Write-Verbose "Starting: $($MyInvocation.Mycommand)" 
            #get policy keys for two main per-computer keys where policy is stored
            #NOTE that this script could be extended to add HKCU per-user keys but as of today--no good mechanisms exist
            #for triggering per-user configuration in DSC
            $policies = Recurse_PolicyKeys -key "HKLM\Software\Policies" -gpo $gpo
            
            $policies += Recurse_PolicyKeys -key "HKLM\Software\Microsoft\Windows NT\CurrentVersion" -gpo $gpo
            
            # build the DSC configuration doc
            GenConfigDoc -path $path -gpo $gpo -policies $policies
            # add error/debug and verbose.
        }

        function Recurse_PolicyKeys
        # This function goes through the registry.pol data and finds entries associated with the 
        # two policy hives mentioned above. Consider rename of the function to be more modular and 
        # powershell'ish
        {
            [cmdletbinding()]
            param
            (
                [string]$key,
                [string]$gpoName
            )
             Write-Verbose "Starting: $($MyInvocation.Mycommand)" 
            # Get-GPRegistryValue is from the GroupPolicy PowerShell module.
            Write-Verbose "Getting GPRegistry value $key from $gponame"

            $current = Get-GPRegistryValue -Name $gpo -Key $key  -ErrorAction SilentlyContinue
            if ($current -eq $null) #means we didn't get a reference to the key being called--probably beause there's no pol settings under it
            {
                return
            }
            foreach ($item in $current)
            {
                if ($item.ValueName -ne $null)
                {
                    [array]$returnVal += $item
                }
                else
                {
                    #this handles the case where we're on a container (i.e. keypath) that doesn't have a value
                    Recurse_PolicyKeys -Key $item.FullKeyPath -gpoName $gpo
                }
            }
            return $returnVal
            
        }

        function GenConfigDoc
        # consider rename of function - New-DSCDoc
        # add verbose output, error handling and debugging
        {
            [cmdletbinding()]
            param
            (
                [string] $path,
                [string] $gpo,
                [array] $policies
            )

             Write-Verbose "Starting: $($MyInvocation.Mycommand)" 
            #parse the spaces out of the GPO name, since we use it for the Configuration name
            $gpo = ($gpo -replace " ","_").toLower()
            $gpo = $gpo -replace "-","_"
            $gpo = $gpo -replace "___","_"
            $gpo = $gpo -replace "__","_"
            $outputFile = "$path\${gpo}.pp"
            Write-Verbose "Saving config to $outputFile"
           
            '# Auto-generated GPO settings' | out-file -FilePath $outputFile -Append -Encoding unicode
            '#' | out-file -FilePath $outputFile -Append -Encoding unicode
            '# @summary Auto-generated GPO settings' | out-file -FilePath $outputFile -Append -Encoding unicode
            '#' | out-file -FilePath $outputFile -Append -Encoding unicode
            '# @example' | out-file -FilePath $outputFile -Append -Encoding unicode
            "#   include module::gpo_${gpo}" | out-file -FilePath $outputFile -Append -Encoding unicode
            "class  gpo_${gpo} {" | out-file -FilePath $outputFile -Append -Encoding unicode
        
            foreach ($regItem in $policies)
            {
                if ($regItem.FullKeyPath -eq $null) #throw away any blank entries
                {
                     continue
                }
                #this next bit guarantees a unique DSC resource name by adding each registry resource name to a hashtable. If found, we increment the key index and append to resource name
                $resourceName = ""
                if ($script:valueNameHashTable.ContainsKey($regItem.ValueName))
                {
                    $script:valueNameHashTable[$regItem.ValueName] = $script:valueNameHashTable[$regItem.ValueName]+1
                    $resourceName = $regItem.ValueName+$script:valueNameHashTable[$regItem.ValueName]
                }
                else
                {
                    $script:valueNameHashTable.Add($regItem.ValueName,0)
                    $resourceName = $regItem.ValueName
                }
                # now build the resources
                # exploring other ways to create the resource info.
                # added unicode encoding to valuename and data to support that type for certain policies (e.g. SRP/Applocker)
                "    dsc_registry { '" + $resourceName + "':"| out-file -FilePath $outputFile -Append -Encoding unicode
                "      dsc_ensure    => 'Present'," | out-file -FilePath $outputFile -Append -Encoding unicode
                "      dsc_key       => '"+ $regItem.FullKeyPath + "',"| out-file -FilePath $outputFile -Append -Encoding unicode
                "      dsc_valueName => '" + $regItem.ValueName + "'," | out-file -FilePath $outputFile -Append -Encoding unicode
                "      dsc_valueType => '" +$regItem.Type + "'," | out-file -FilePath $outputFile -Append -Encoding unicode
                # need to trim any nul characters from ValueData (mostly an Applocker issue)
                $trimValue = $regItem.Value.ToString().Trim("`0")
                "      dsc_valueData => '" +$trimValue + "',"| out-file -FilePath $outputFile -Append -Encoding unicode
                '    }' | out-file -FilePath $outputFile -Append -Encoding unicode
                ''  | out-file -FilePath $outputFile -Append -Encoding unicode
            }
            '}'  | out-file -FilePath $outputFile -Append -Encoding unicode
            ''  | out-file -FilePath $outputFile -Append -Encoding unicode
        }
    } #begin
    
    Process
    {
        #this hash table holds valuename, which we use to name registry resources--guarantees that they are unique
        $script:valueNameHashTable = @{}
       
        Write-Verbose "Analyzing GPO $gponame and saving results to $outputfolder"
        ADMToDSC -gpo $gpoName -path $outputFolder
        #ISE "$outputfolder\$gponame.ps1"
    }

    End {
        Write-Verbose "Ending: $($MyInvocation.Mycommand)"
    } #end
}

