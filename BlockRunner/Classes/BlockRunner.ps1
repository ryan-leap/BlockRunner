
<#
   Want this class to be in its own file but haven't gotten the build
   process right to bring it properly in scope yet.
   Data type returned by a BlockRunner run

   A PSSession has a transport so that's why I chose that property name
   - Add FlattenObject() method
#>
class BlockRunnerResult {
    [string] $ComputerName
    [bool] $Online
    [Object] $Result
    [String] $Transport
    [TimeSpan] $Elapsed
    [System.Exception] $Exception
}

<#
    Class that handles the details of running remote jobs

    To do:
    Rename?  New-ScriptBlock, New-ScriptBlockRunner
    1. Use New-PSSession with appropriate options (instead of invoke-command -computername) so
       you can take advantage of the various session options (transport, timeouts).  Maybe
       New-BlockRunner should take a session option parameter with the default being what
       New-SessionOption returns.
    2. Okay...so suppose WinRm isn't open meaning Invoke-Command is a no go.  Want to try to implement
       this?  Base 64 encode scriptblock.  Invoke-CimMethod new process powershell.exe -encodedcommand.
       Why not?
    3. Implement ThreadJob
#>
class BlockRunner {

    hidden [ScriptBlock] $ScriptBlock
    hidden [Object[]] $ArgumentList
    hidden [PSCredential] $Credential
    hidden [int] $ThrottleLimit
    [string[]] $ComputerName

    BlockRunner ([ScriptBlock] $ScriptBlock,
                 [Object[]] $ArgumentList,
                 [PSCredential] $Credential,
                 [int] $ThrottleLimit) {

        $this.ScriptBlock = $ScriptBlock
        $this.ArgumentList = $ArgumentList
        $this.Credential = $Credential
        $this.ThrottleLimit = $ThrottleLimit

    }

    # Utility to split computer list according to throttle size
    hidden [Object[]] SplitComputerList () {
        $divisor = [math]::Ceiling($this.ComputerName.Count / $this.ThrottleLimit)
        if ($divisor -ge $this.ComputerName.Count) {
            return $this.ComputerName
        }
        else {
            [int] $remainder = 0
            $quotient = [math]::DivRem($this.ComputerName.Count, $divisor, [ref]$remainder)
            $splitComputerList = @()
            for ($i = 0; $i -lt $divisor; $i++) {
                $splitComputerList += ,($this.ComputerName | Select-Object -Skip ($i * $quotient) -First $quotient)
            }
            if ($remainder -gt 0) {
                $splitComputerList += ,($this.ComputerName | Select-Object -Last $remainder)
            }
        }
        return $splitComputerList
    }

    # Method which will run scriptblock provided against computer list
    [Object[]] Run() {
        $blockRunnerResults = [System.Collections.ArrayList]::new()
        if ($null -eq $this.ComputerName) {
            return $null
        }

        $localJobScriptBlock = {
            param (
                [Object] $BlockResult,
                [String] $ComputerName,
                [String] $ScriptBlockAsString,
                [Object[]] $ArgumentList,
                [PSCredential] $Credential
            )

            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $BlockResult.ComputerName = $ComputerName

            # Experienced issues passing a script block into a script block so instead we pass
            # in a string which represents a script block and turn it into a real script block
            $scriptBlock = [scriptblock]::Create($ScriptBlockAsString)
            $splatArgs = @{
                'ComputerName' = $ComputerName
                'ScriptBlock'  = $scriptBlock
                'ArgumentList' = $ArgumentList
                'Credential'   = $Credential
            }
            if ($env:COMPUTERNAME -eq $ComputerName) {
                $splatArgs.Add('EnableNetworkAccess', $true)
                $BlockResult.Online = $true
            }
            else {
                # Test-Connection (protocols), $BlockResult.Online = $true or $false
            }
            if ($BlockResult.Online) {
                Try {
                    $BlockResult.Result = Invoke-Command @splatArgs -ErrorAction Stop
                }
                Catch {
                    $BlockResult.Exception = $_.Exception
                }
            }
            $stopWatch.Stop()
            $BlockResult.Elapsed = $stopWatch.Elapsed
            $BlockResult
        }

        if ($false) { #($null = Get-Command -Module ThreadJob) {
            # Start-ThreadJob
        }
        else {
            $splitComputerList = $this.SplitComputerList()
            foreach ($computerList in $splitComputerList) {
                foreach ($computer in $computerList) {
                    Write-Verbose "Starting job on [$computer]..."
                    $localJobArgList = @([BlockRunnerResult]::new(), $computer, $this.ScriptBlock.ToString(), $this.ArgumentList, $this.Credential) 
                    $splatStartJob = @{
                        'Name'         = $this.ScriptBlock.Id.Guid + '_' + $computer
                        'ScriptBlock'  = $localJobScriptBlock
                        'ArgumentList' = $localJobArgList
                    }
                    $null = Start-Job @splatStartJob
                    Write-Verbose "Starting job on [$computer] complete."
              }
              $blockRunnerResults.Add((Get-Job -Name ($this.ScriptBlock.Id.Guid + '*') | Receive-Job -AutoRemoveJob -Wait))
            }
        }
        return $blockRunnerResults.ToArray()
    } # End Method

    [Object[]] Run([switch] $Verbose)
    {
        [System.Management.Automation.ActionPreference] $verboseState = $Global:VerbosePreference
        if ($Verbose) {
          $Global:VerbosePreference = 'Continue'
        }
        $results = $this.Run()
        if ($Verbose) {
          $Global:VerbosePreference = $verboseState
        }
        return $results
    }

} # End Class