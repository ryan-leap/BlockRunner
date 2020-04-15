<#
   If you end up adding support for multiple ways of reaching a remote
   compute then adding a 'transport' property or 'protocol' or something
   to that affect to the BlockRunnerResult object would be nice.
#>
class BlockRunnerResult {
    [string] $ComputerName
    [bool] $Available
    [Object] $Result
    [TimeSpan] $Elapsed
    [System.Exception] $Exception
}