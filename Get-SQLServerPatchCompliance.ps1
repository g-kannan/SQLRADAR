<#
.SYNOPSIS
  Script to Get Compliance report on SQL Server Patches
.DESCRIPTION
  This Script compares version of each SQL Instance given as Input with latest build numbers specified. 
  This script depends on modules "DBATools" & "PSWRITEHTML"(for HTML output only)
.PARAMETER <SQLInstance>
    One or more SQL Instance List
.PARAMETER <Credential>
    Credential to connect SQL Instance(s)    
.INPUTS
  SQLInstance
.OUTPUTS
  Output to console(Default)
  Use Switch -HTMLOutput to open output in Browser(HTML)
.NOTES
  Version:        1.0
  Author:         Kannan
  Creation Date:  27FEB2022
  Purpose/Change: SQL Server Patch Compliance Check
  
.EXAMPLE
  Get-SQLServerPatchCompliance -SQLInstance '192.168.0.109' -Credential $SQLCred  
  Get-SQLServerPatchCompliance -SQLInstance '192.168.0.109' -Credential $SQLCred  -HTMLOutput

#Sample Output
1 / 1 SQLInstances requires latest patches to be installed. Percent-Compliant = 0.00 %

SQLInstance   Version CurrentBuild LatestBuild UpdateRequired DaysSinceRelease
-----------   ------- ------------ ----------- -------------- ----------------
192.168.0.109 2019    15.0.2000.5  15.0.4198.2 Yes                          31
#>


#----------------------------[Declarations]---------------------------#

$FinalResults = @()

#Update List as and when new patch released
$LatestBuild =
@(
    @{Version = '2019'; VersionMajor = 15; LatestBuildNo = '15.0.4223.1'; ReleaseDate = '2022-04-18'; UpdateDesc = 'CU16' }
    @{Version = '2017'; VersionMajor = 14; LatestBuildNo = '14.0.3436.1'; ReleaseDate = '2022-03-30'; UpdateDesc = 'CU29' }
    @{Version = '2016'; VersionMajor = 13; LatestBuildNo = '13.0.6300.2'; ReleaseDate = '2021-09-15'; UpdateDesc = 'SP3' }
    @{Version = '2014'; VersionMajor = 12; LatestBuildNo = '12.0.6433.1'; ReleaseDate = '2021-01-12'; UpdateDesc = 'SP3-CU4' }
    @{Version = '2012'; VersionMajor = 11; LatestBuildNo = '11.0.7507.2'; ReleaseDate = '2021-01-12'; UpdateDesc = 'SP4-GDR' }
)


#----------------------------[Function]---------------------------#
function Get-SQLServerPatchCompliance {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        #SQLInstance
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [String[]]$SQLInstance,

        #Credential
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty ,

        #Enable Switch if HTML Output required
        [switch]
        $HTMLOutput
    )
    foreach ($Instance in $SQLInstance) {
        $EachVersion = Get-DbaInstanceProperty -SqlInstance $SQLInstance -SqlCredential $Credential -InstanceProperty VersionString | Select-Object -ExpandProperty value
        $VerProp = $EachVersion.split(".")
        #Compare with Latest
        $LVersion = $LatestBuild | Where-Object VersionMajor -EQ $VerProp[0]
        if ($EachVersion -eq $LVersion.LatestBuildNo) { $UpdateRequired = 'No' }
        else {
            $UpdateRequired = 'Yes'
        }
        $DaysSinceRelease = New-TimeSpan -Start $LVersion.ReleaseDate -End (get-Date) | Select-Object -ExpandProperty Days
        $InstanceCheck = [PSCustomObject]@{SQLInstance = $Instance; Version = $LVersion.Version; CurrentBuild = $EachVersion; LatestBuild = $LVersion.LatestBuildNo; UpdateRequired = $UpdateRequired; DaysSinceRelease = $DaysSinceRelease }
        #$LoopArray = [pscustomobject]$InstanceCheck
        $FinalResults += $InstanceCheck
    }
  
    #Compliance % Calculations
    $TotalInstances = $FinalResults.SQLInstance
    $TotalCount = $TotalInstances.Count
    $OutDatedInstances = $FinalResults | Where-Object UpdateRequired -EQ 'Yes' | Select-Object SQLInstance
    $outDatedInstanceCount = $OutDatedInstances.Count

    $Compliance = $outDatedInstanceCount / $TotalCount

    try {
        $Compliance = (($TotalCount - $outDatedInstanceCount) / $TotalCount).Tostring("P")
    }
    catch {
        $Compliance = 0
    }

    $Summary = "$($outDatedInstanceCount) / $($TotalCount) SQLInstances requires latest patches to be installed. Percent-Compliant = $($Compliance) "
    Write-Output -InputObject $Summary
    $FinalResults | Format-Table -AutoSize


    #Results to HTML
    if ($HTMLOutput -eq $true) {
        New-HTML {

            New-HTMLHeading -HeadingText "SQL Server Patch Compliance Report" -Heading h1
            New-HTMLHeading -HeadingText "$Summary" -Heading h2
            New-HTMLPanel -Invisible {
                New-HTMLTable -DataTable $FinalResults -Title 'SQL Server Update Status' -HideFooter   #-Simplify
            }
        } -ShowHTML
    }

}
