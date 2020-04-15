
#
# Patterned after @devblackops https://leanpub.com/building-powershell-modules
# dot sourcing Module Layout
#

# Dot sources in classes
. .\Classes\BlockRunnerResult.ps1
. .\Classes\BlockRunner.ps1

# Dot source public/private functions
$publicFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1'
$privateFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1'
$public = @(Get-ChildItem -Path $publicFunctionsPath -Recurse -ErrorAction Stop)
$private = @(Get-ChildItem -Path $privateFunctionsPath -Recurse -ErrorAction Stop)
foreach ($file in @($public + $private)) {
    try {
        . $file.FullName
    }
    catch {
        throw "Unable to dot source [$($file.FullName)]"
    }
}

# Define aliases
$aliases = @()
$aliases += New-Alias -Name nbr -Value New-BlockRunner -PassThru
Export-ModuleMember -Function $public.BaseName -Alias $aliases.Name