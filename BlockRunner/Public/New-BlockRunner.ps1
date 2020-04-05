function New-BlockRunner {
    <#
    .SYNOPSIS
        Creates a script block runner.  A script block runner simplifies running PoweShell code
        against a list of computers.
    .DESCRIPTION
        Prepares an object that can run a block of PowerShell code against a list of computers. The block
        runner abstracts away the complexity of managing jobs/threads and remote connectivity.  The caller
        only needs to provide the code to run (script block) and the list of computers on which to run it.
        The block runner manages the rest of the process.
    .PARAMETER ComputerName
        Specifies the computers on which the command runs. The default is the local computer.
    .PARAMETER ScriptBlock
        Specifies the commands to run. Enclose the commands in curly braces `{ }` to create a script block.
    .PARAMETER ArgumentList
        Supplies the values of local variables in the command. The variables in the command are replaced by
        these values before the command is run on the remote computer. Enter the values in a comma-separated
        list. Values are associated with variables in the order that they're listed.
    .PARAMETER Credential
        Specifies a user account that has permission to perform this action. The default is the current user.
    .PARAMETER ThrottleLimit
        This parameter limits the number of jobs running at one time.
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string[]] $ComputerName = $ENV:COMPUTERNAME,

        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock,

        [Parameter(Mandatory=$false)]
        [Object[]] $ArgumentList,

        [Parameter(Mandatory=$false)]
        [PSCredential] $Credential = [System.Management.Automation.PSCredential]::Empty,

        [ValidateRange(1,1000)]
        [Parameter(Mandatory=$false)]
        [int] $ThrottleLimit = 25
    )
    
    begin {
        . "$PSScriptRoot\..\Classes\BlockRunner.ps1"
    }
    
    process {
        $blockRunner = [BlockRunner]::new($ScriptBlock, $ArgumentList, $Credential, $ThrottleLimit)
        $blockRunner.ComputerName = $ComputerName
        $blockRunner
    }
    
    end {
    }
}