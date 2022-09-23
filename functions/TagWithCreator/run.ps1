<#
.SYNOPSIS
  This Azure Function is used to tag new resource groups with the user name of the creator.
.DESCRIPTION
  ****This script provided as-is with no warranty. Test it before you trust it.****
  Event Grid send a trigger to the Azure Function when a resource group is added to a subscription.  
  Advanced filters in Event Grid limit the alter to a defined data type.  
  Resource types are specified in the input data from Event Grid.  Resource Provider Operations are listed in the document:
  https://docs.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations#microsoftcompute
  The Azure function formats the tag and value from the Event Grid data.
  Azure function applies the tag and tag value to the resource group.
.INPUTS
  Data passed in from Event Grid
.OUTPUTS
  Errors write to the Error stream
  Logging and test data writes to the Output stream
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  4/27/2021
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  TBD
#>


# Parameter Name must match bindings
param($eventGridEvent, $TriggerMetadata)

# Get the day in Month Day Year format
$date = Get-Date -Format "MM/dd/yyyy"
# Add tag and value to the resource group
$nameValue = $eventGridEvent.data.claims.name
$tagsupdate = @{"Creator"="$nameValue";"DateCreated"="$date"}

$caller = $eventGridEvent.data.claims.name
if ($null -eq $caller) {
    if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
        $caller = (Get-AzADServicePrincipal -ObjectId $eventGridEvent.data.authorization.evidence.principalId).DisplayName
        if ($null -eq $caller) {
            Write-Host "MSI may not have permission to read the applications from the directory"
            $caller = $eventGridEvent.data.authorization.evidence.principalId
        }
    }
}

write-output "Tags:"
write-output $tagsupdate

# Resource Group Information:

$rgURI = $eventGridEvent.data.resourceUri
write-output "rgURI:"
write-output $rgURI
Write-Host "Caller: $caller"
Write-Host "ResourceId: $rgURI"

if (($null -eq $caller) -or ($null -eq $rgURI)) {
    Write-Host "ResourceId or Caller is null"
    exit;
}

$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags")

foreach ($case in $ignore) {
    if ($rgURI -match $case) {
        Write-Host "Skipping event as resourceId contains: $case"
        exit;
    }
}

$tags = (Get-AzTag -ResourceId $rgURI).Properties

if (!($tags.TagsProperty.ContainsKey('Creator')) -or ($null -eq $tags)) {
    Update-AzTag -ResourceId $rgURI -Operation Merge -Tag $tagsupdate
    Write-Host "Added creator tag with user: $caller"
} else {
    Write-Host "Tag already exists"
}