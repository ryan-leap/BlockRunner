

<#
    Class that handles the details of running remote jobs

    1. In New-BlockRunner have a param which takes a SessionOption
    2. Use sessions for invoke-command
    3. Implement ThreadJob
    4. Should you: Make ThreadJob a dependency?
    5. Should you: Have an -ExecutionOption param with these options:
       Batch | Job | ThreadJob | Negotiate (Default of Negotiate)
       Thinking instead that the Run() method should have the option.
       Maybe an Enum.  Either way, do it if you can validate.
    6. For -Verbose and -Debug should New-BlockRunner set properties for
       the BlockRunner instantiation that set it to whatever option was used
       when New-BlockRunner was called?  Probably not.  I guess I'd like there
       to be a way to set a property though for Verbose and Debug for the Run method
       without using the method signature, but rather for the class.
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
        Write-Debug "[BlockRunner] [Run()] method."
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
                $BlockResult.Available = $true
            }
            else {
                $BlockResult.Available = Try {
                    $null = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
                    $true
                }
                Catch {
                    $false
                }
            }
            if ($BlockResult.Available) {
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
        # Not sure it is appropriate to set the script scope for this...will it enable
        # verbose for scripts calling this script?
        if ($Verbose) {
          $Script:VerbosePreference = 'Continue'
        }
        return $this.Run()
    }

} # End Class