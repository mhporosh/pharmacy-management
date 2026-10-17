<#
.Synopsis
Activate a Python virtual environment for the current PowerShell session.

.Description
Pushes the python executable for a virtual environment to the front of the
$Env:PATH environment variable and sets the prompt to signify that you are
in a Python virtual environment. Makes use of the command line switches as
well as the `pyvenv.cfg` file values present in the virtual environment.

.Parameter VenvDir
Path to the directory that contains the virtual environment to activate. The
default value for this is the parent of the directory that the Activate.ps1
script is located within.

.Parameter Prompt
The prompt prefix to display when this virtual environment is activated. By
default, this prompt is the name of the virtual environment folder (VenvDir)
surrounded by parentheses and followed by a single space (ie. '(.venv) ').

.Example
Activate.ps1
Activates the Python virtual environment that contains the Activate.ps1 script.

.Example
Activate.ps1 -Verbose
Activates the Python virtual environment that contains the Activate.ps1 script,
and shows extra information about the activation as it executes.

.Example
Activate.ps1 -VenvDir C:\Users\MyUser\Common\.venv
Activates the Python virtual environment located in the specified location.

.Example
Activate.ps1 -Prompt "MyPython"
Activates the Python virtual environment that contains the Activate.ps1 script,
and prefixes the current prompt with the specified string (surrounded in
parentheses) while the virtual environment is active.

.Notes
On Windows, it may be required to enable this Activate.ps1 script by setting the
execution policy for the user. You can do this by issuing the following PowerShell
command:

PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

For more information on Execution Policies: 
https://go.microsoft.com/fwlink/?LinkID=135170

#>
Param(
    [Parameter(Mandatory = $false)]
    [String]
    $VenvDir,
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt
)

<# Function declarations --------------------------------------------------- #>

<#
.Synopsis
Remove all shell session elements added by the Activate script, including the
addition of the virtual environment's Python executable from the beginning of
the PATH variable.

.Parameter NonDestructive
If present, do not remove this function from the global namespace for the
session.

#>
function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_VIRTUAL_PROMPT) {
        Copy-Item -Path Function:_OLD_VIRTUAL_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_VIRTUAL_PROMPT
    }

    # The prior PYTHONHOME:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PYTHONHOME) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME -Destination Env:PYTHONHOME
        Remove-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PATH) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_VIRTUAL_PATH
    }

    # Just remove the VIRTUAL_ENV altogether:
    if (Test-Path -Path Env:VIRTUAL_ENV) {
        Remove-Item -Path env:VIRTUAL_ENV
    }

    # Just remove VIRTUAL_ENV_PROMPT altogether.
    if (Test-Path -Path Env:VIRTUAL_ENV_PROMPT) {
        Remove-Item -Path env:VIRTUAL_ENV_PROMPT
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Scope Global -Force
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

<#
.Description
Get-PyVenvConfig parses the values from the pyvenv.cfg file located in the
given folder, and returns them in a map.

For each line in the pyvenv.cfg file, if that line can be parsed into exactly
two strings separated by `=` (with any amount of whitespace surrounding the =)
then it is considered a `key = value` line. The left hand string is the key,
the right hand is the value.

If the value starts with a `'` or a `"` then the first and last character is
stripped from the value before being captured.

.Parameter ConfigDir
Path to the directory that contains the `pyvenv.cfg` file.
#>
function Get-PyVenvConfig(
    [String]
    $ConfigDir
) {
    Write-Verbose "Given ConfigDir=$ConfigDir, obtain values in pyvenv.cfg"

    # Ensure the file exists, and issue a warning if it doesn't (but still allow the function to continue).
    $pyvenvConfigPath = Join-Path -Resolve -Path $ConfigDir -ChildPath 'pyvenv.cfg' -ErrorAction Continue

    # An empty map will be returned if no config file is found.
    $pyvenvConfig = @{ }

    if ($pyvenvConfigPath) {

        Write-Verbose "File exists, parse `key = value` lines"
        $pyvenvConfigContent = Get-Content -Path $pyvenvConfigPath

        $pyvenvConfigContent | ForEach-Object {
            $keyval = $PSItem -split "\s*=\s*", 2
            if ($keyval[0] -and $keyval[1]) {
                $val = $keyval[1]

                # Remove extraneous quotations around a string value.
                if ("'""".Contains($val.Substring(0, 1))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }

                $pyvenvConfig[$keyval[0]] = $val
                Write-Verbose "Adding Key: '$($keyval[0])'='$val'"
            }
        }
    }
    return $pyvenvConfig
}


<# Begin Activate script --------------------------------------------------- #>

# Determine the containing directory of this script
$VenvExecPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvExecDir = Get-Item -Path $VenvExecPath

Write-Verbose "Activation script is located in path: '$VenvExecPath'"
Write-Verbose "VenvExecDir Fullname: '$($VenvExecDir.FullName)"
Write-Verbose "VenvExecDir Name: '$($VenvExecDir.Name)"

# Set values required in priority: CmdLine, ConfigFile, Default
# First, get the location of the virtual environment, it might not be
# VenvExecDir if specified on the command line.
if ($VenvDir) {
    Write-Verbose "VenvDir given as parameter, using '$VenvDir' to determine values"
}
else {
    Write-Verbose "VenvDir not given as a parameter, using parent directory name as VenvDir."
    $VenvDir = $VenvExecDir.Parent.FullName.TrimEnd("\\/")
    Write-Verbose "VenvDir=$VenvDir"
}

# Next, read the `pyvenv.cfg` file to determine any required value such
# as `prompt`.
$pyvenvCfg = Get-PyVenvConfig -ConfigDir $VenvDir

# Next, set the prompt from the command line, or the config file, or
# just use the name of the virtual environment folder.
if ($Prompt) {
    Write-Verbose "Prompt specified as argument, using '$Prompt'"
}
else {
    Write-Verbose "Prompt not specified as argument to script, checking pyvenv.cfg value"
    if ($pyvenvCfg -and $pyvenvCfg['prompt']) {
        Write-Verbose "  Setting based on value in pyvenv.cfg='$($pyvenvCfg['prompt'])'"
        $Prompt = $pyvenvCfg['prompt'];
    }
    else {
        Write-Verbose "  Setting prompt based on parent's directory's name. (Is the directory name passed to venv module when creating the virtual environment)"
        Write-Verbose "  Got leaf-name of $VenvDir='$(Split-Path -Path $venvDir -Leaf)'"
        $Prompt = Split-Path -Path $venvDir -Leaf
    }
}

Write-Verbose "Prompt = '$Prompt'"
Write-Verbose "VenvDir='$VenvDir'"

# Deactivate any currently active virtual environment, but leave the
# deactivate function in place.
deactivate -nondestructive

# Now set the environment variable VIRTUAL_ENV, used by many tools to determine
# that there is an activated venv.
$env:VIRTUAL_ENV = $VenvDir

$env:VIRTUAL_ENV_PROMPT = $Prompt

if (-not $Env:VIRTUAL_ENV_DISABLE_PROMPT) {

    Write-Verbose "Setting prompt to '$Prompt'"

    # Set the prompt to include the env name
    # Make sure _OLD_VIRTUAL_PROMPT is global
    function global:_OLD_VIRTUAL_PROMPT { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_VIRTUAL_PROMPT
    New-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Description "Python virtual environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_PYTHON_VENV_PROMPT_PREFIX) "
        _OLD_VIRTUAL_PROMPT
    }
}

# Clear PYTHONHOME
if (Test-Path -Path Env:PYTHONHOME) {
    Copy-Item -Path Env:PYTHONHOME -Destination Env:_OLD_VIRTUAL_PYTHONHOME
    Remove-Item -Path Env:PYTHONHOME
}

# Add the venv to the PATH
Copy-Item -Path Env:PATH -Destination Env:_OLD_VIRTUAL_PATH
$Env:PATH = "$VenvExecDir$([System.IO.Path]::PathSeparator)$Env:PATH"

# SIG # Begin signature block
# MII27gYJKoZIhvcNAQcCoII23zCCNtsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBALKwKRFIhr2RY
# IW/WJLd9pc8a9sj/IoThKU92fTfKsKCCG1wwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwgga6MIIEoqADAgECAhMzAAc2rufu
# H4G0QASuAAAABzauMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDMwHhcNMjYwOTI5MDkxNDE0WhcNMjYxMDAy
# MDkxNDE0WjB8MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGT3JlZ29uMRIwEAYDVQQH
# EwlCZWF2ZXJ0b24xIzAhBgNVBAoTGlB5dGhvbiBTb2Z0d2FyZSBGb3VuZGF0aW9u
# MSMwIQYDVQQDExpQeXRob24gU29mdHdhcmUgRm91bmRhdGlvbjCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBALMR3EsrjOoOJcocO8sl5H6JHkogAX3QOUCA
# 6+6imuE7JW/ZXkWR7N3cReFZnVeVbT7xB0MP9wikb/gZogKFV1gNJHfgDxy1/jeI
# 6gZ2kWI3lsSq6VTKh4Umx8VVn++Ap3wDr65HH2tVFZ2/YGkMx1fdSSX5k6aj0GRO
# kI39t6KWsLkwVketKdARimq/6N7i3jMAqJMmhFBDHZolEE2JSm68gU6zWJbWLYcN
# k2wN9lMGkaGKifVHE8HN/9A2/e3Pmg6zczi86cooe3hokrkVUCpvWtA689LCyfxk
# /o53rI+0VoqkTuT26+MLs5j584fJLHhZHZ39xMJkz3z1lckH5CaQWeXczC4EBOTY
# lMBMxt9oC4zgNDMesCq9cTyWFeQJa/ykpFamCwRyU2pjmEHddFhr2dnGEk+rGZYE
# 1ohGLn/0ajih9L7FQpC4y8kMT7KsyHY0/NmYR0vR7dD6NSO4BobURZjkgqcaX2xl
# 8IsjwvCvYQJ8bdpi+GDLeeyy/MvtBwIDAQABo4IB1TCCAdEwDAYDVR0TAQH/BAIw
# ADAOBgNVHQ8BAf8EBAMCB4AwPAYDVR0lBDUwMwYKKwYBBAGCN2EBAAYIKwYBBQUH
# AwMGGysGAQQBgjdhgqKNuwqmkohkgZH0oEWCk/3hbzAdBgNVHQ4EFgQU5nE109WE
# AwyNVnQS4aE0pfMeBH4wHwYDVR0jBBgwFoAUa16lNMMFxWJKIVqOq3NgYtSsY4Uw
# ZwYDVR0fBGAwXjBcoFqgWIZWaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0El
# MjAwMy5jcmwwdAYIKwYBBQUHAQEEaDBmMGQGCCsGAQUFBzAChlhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVy
# aWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDMuY3J0MFQGA1UdIARNMEswSQYEVR0g
# ADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wDQYJKoZIhvcNAQEMBQADggIBAAqJk3xyS3QH
# Ol3Yp8gCp6Xf6E9ntAwQSRBtAMNo84/JsAFvNvc/8SibRF8bOTcSALYXTJddpynA
# No3YZP0dIV60BLAZUP68FP/eeb3u2X/W2TXCBUKbqB++7UXXqXIB9xF/LKYkpQ/U
# 6LDMztFez+Wtkgt/vo0lObrvpCE6tKxCZySou3pEVer21TnWdfAsWO8JMJy61kXs
# bGGzRxqamo6VfD2gRQ1kcmqSihEgGF0z//lOyIRKtidN+N1JwpKY2CJkRybzhm8L
# gBmfO5GrBmvrB65Y8QzXgPV9O9NCQdSjCO2A45FFJbp4ezm1CsdCAzp6zZxdpnjR
# gQjCtNqDVMm3bx2LjSOioK6zEZJowdcH+oUoLg97rfB03nI5tDTg0MCc1zwH6kaW
# MY1Y9VkAPvpX8PpdK8r3CUXmxJL5Ct2I46RYyRw9ygC3mXqe+ZhvZtGFuyUsBtsl
# LwooPaaaT7o5D9kMvgLR0KbdjNHxNo9prFKBxzB+6+xDKyzq9Ne7uLJpnQarORbU
# EExIWeUTOVqhuQAabTttNZfTudu/WaUQYErxQr8EMVX96r4FbT9SXumj03YvedqH
# 9ZOGZF6JaYNTCW2mP9QP5oTqW/EM7Yyyl1u63Sttn9y+ZdjehUovvW+UaLi5o3ql
# rEjXRyk1L3dSCev03lwvmNiF5v2lYFhLMIIHKDCCBRCgAwIBAgITMwAAABUFPm4Z
# jpMp2QAAAAAAFTANBgkqhkiG9w0BAQwFADBjMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQDEytNaWNyb3NvZnQgSUQg
# VmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMB4XDTI2MDMyNjE4MTEyOFoX
# DTMxMDMyNjE4MTEyOFowWjELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0IElEIFZlcmlmaWVkIENT
# IEVPQyBDQSAwMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOD0yz0C
# qi8Ocx4+8w574rJuEJ3z6WiTNg5GVLeQFVex55xvIbAFyx6eWblsu0wY+OIgUvMF
# AX6CGVVX9Tb2rkZx14QQEIdNMaEvaSgistzhSuWIxFxu/2Y4y1H+Xv/ECa/QXHgE
# kefV0e3ft++sGpeYqMp8Z/kOnI7/6GdXtMSt4y1LX2I75uNn/0eemDc8KTR7thJt
# FMWTH3sVnBFakLizc16lF9FdCH9YwCPsmaxh5VmiGLhMXnJbYkyslmrAdzLMlli0
# PYeWejlkQmR2JlwRrEc6hubA7TpnUn1zbemz08YiEZqrWwosQDP0OhzmsuRhYa14
# OuxwqECnaQhz+hiUf0iPoGQ6qqBYg0SQS0Lxk0bUxqT6HejrlqPSJAqZ3Fbshloc
# 7ly7KgyL4q1h9d4giDexUhtLYQvyRS2wMZ0So2oCr+KypOLWNeot7qIqnWeLVI92
# 89b0bTcJOxgXrxv/K4hBHBt2gEJd6Yw0kJLR2isJFjhvZYADLieDtIA1wSCsGBl/
# nfn5B8tTmEbOsqMilsxptq5ZvkUpZQqQyw9xcWRdFY7iego+bgpaUXKmo6lsn8o4
# 1VF4iXEdBF6AA4HMiFEHuCv0gNDWxzYyA6BD7FUZbiirgcPSZ8CLCLIuyRmuRpDs
# mhqdiME1xH1FLbpjEBVtwG0uK0VPMIgSDll1AgMBAAGjggHcMIIB2DAOBgNVHQ8B
# Af8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFGtepTTDBcViSiFa
# jqtzYGLUrGOFMFQGA1UdIARNMEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwEgYDVR0TAQH/BAgwBgEB/wIBADAf
# BgNVHSMEGDAWgBTZQSmwDw9jbO9p1/XNKZ6kSGow5jBwBgNVHR8EaTBnMGWgY6Bh
# hl9odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQl
# MjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDIxLmNy
# bDB9BggrBgEFBQcBAQRxMG8wbQYIKwYBBQUHMAKGYWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUy
# MENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcnQwDQYJKoZIhvcNAQEMBQAD
# ggIBAF1uIjzPBctfyCUkSH/xDbZQwJSFYE7jpn0U+HA5HeZ2WpFUuRg6if8xzNTC
# uMOHHdf31I8fk9J+WQahO+c71lYczlgVVik7s1i4H6Z9VIYAZnCIY4BJaTSLYHu+
# f2cSUkmaiJfG6B8flh0GytSBO3QAU1eTOapOCT5LUfFvW7/QcKoQdVk+TYD/p4ld
# hu2lEzkVzPTSOKxSX0FFmBJ5s4NXzlsHM696rILd/Q+ccLFEk2ExvzE/+wH9Ujul
# /auF5JXvOpRK/y+f98gxuVd5pUiWmqirxI/0EkyMT8KhVcnGeRlBEzUVruQ33LO2
# 9F46HFKA+ClnH9eX+OTDIQVUlMF8GnexOB8hz+maq/Z6G1qQvYASPvwSY49CiHEl
# PfDJf4/vwYDbm0ukC/OPdEwwd3zPXxm65WL7rQwDMak4BIfUvw2Wvd9lFmdA76nL
# J7YMK9iYdoh91SBgmqfuejHEZW/z35FoROHW2AIO/A2kUJIbu+XkDhqSj7Z/HjT2
# v1NaNcLs6J/UhDlknMHhF/wa8GIdiO8yYemV52nUUZEt1JEVWkLf84qlljpq8ipm
# nv7yk/9ZA/3TcN2Cu8BPpbjE84HFc9ri0aSw3dK6olqIVgdI3J4G5+fyKx66Nbgh
# sFJscPgE+psXepn7ucb13938bb8vHiQf1wKYF+axl1KQea6QMIIHnjCCBYagAwIB
# AgITMwAAAAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9N
# aWNyb3NvZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBj
# MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQw
# MgYDVQQDEytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAy
# MDIxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpM
# SWxpCFUJtFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoE
# tuxACEGcgHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDp
# xDOxhgf8JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3
# bjaj2QfzZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF
# 9/bjVRo4Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+Hx
# KeJ9bYmPf6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK
# /H04kteZEZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0
# TnRJubL/hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0
# KvBDLHtL8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO
# 2AwwVG4Fre+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn
# +PhUXILhAV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIB
# hjAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhq
# MOYwVAYDVR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEE
# AYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0
# eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0
# eSUyMDIwMjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# SWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBB
# dXRob3JpdHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3Au
# bWljcm9zb2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1m
# CttXI0y6XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58
# HOcA1tcsHQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeA
# hBEjABvIUpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8B
# mQXv5hT2RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1E
# b59PYwISFCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrX
# SfyL2Op6mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+b
# Ha9KhTyzwdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8Hf
# FqNifN6+zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PX
# bjXzGifaIMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygb
# ahmYOHk7VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEok
# uPgNPa6EnTiOL60cPqfny+Fq8UiuZzGCGugwghrkAgEBMHEwWjELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWlj
# cm9zb2Z0IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMwITMwAHNq7n7h+BtEAErgAA
# AAc2rjANBglghkgBZQMEAgEFAKCBtDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# Kld7dFLdvZygPQIm94QeWCWq09RhnYWpKs5R8/oLpjgwSAYKKwYBBAGCNwIBDDE6
# MDigMoAwAFAAeQB0AGgAbwBuACAAMwAuADEAMwAuADEANgAgACgAYwBiAGMAOQA0
# ADQAZgApoQKAADANBgkqhkiG9w0BAQEFAASCAYCtlJ97zAdkohR/6F7JHqtzvtoG
# KPQXOvHUw9NY7FL6x82wI37MwwSygC8Ws8+YNpBJaFpdodDalhQjgYmr1mMPDAee
# 6F9jlZALXKYVNdnM2Em0TE5Q5oojcgw9Ys9TBubBAirYuR9C/CM4j1BnPYa0kvMd
# /ECloR1fWvjG5/bXCVqySBNyoe3EoPL6vOBXpU356nRYGPLRKjmTtXFQDo8huWEd
# Uii1ZTmbi0LaNlBDOmoGXFONtehAmrbIzyM5QqvbML3DNM0XKg26J4A4Hif9wRrE
# eiT5t5h4YMfZ8QydmrB4sAwVqarjLg2Ts6oNvi63owcHtEO4etq8fivQJ8m82aGq
# oRyYKutEFCLi4vLHNuNQUIo/szppMl6EzxcVajO1e3ICP+TpWXYho1CGhE6ODShM
# RZKayrtUBAtKcEuddU79r3lKo1d1doFVqkV07MX4xmb6S5twyb09IhqwID7jLRwA
# ZdEY4QtndOJssbUmGa9PNiUvQYOaAMombAkscbShghgRMIIYDQYKKwYBBAGCNwMD
# ATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQCAQUA
# MIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEwMTAN
# BglghkgBZQMEAgEFAAQgFBkmQ9eA0BWkqRcqZ8pn6grCgV+iq3q1WzCEQ1YqM8gC
# BmqpeCH70hgTMjAyNjA5MzAxOTU2MTUuNTIxWjAEgAIB9KCB4aSB3jCB2zELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9z
# b2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNO
# OjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBU
# aW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAABeXP
# D/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJ
# ZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkg
# MjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eXM9ET
# Bb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3TOYtg
# oBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/Ssah8
# nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i5F9Y
# ciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx69uKq
# KhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3GgZwe
# tEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2HVJo
# 9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT4I7s
# DbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnGnsBC
# d2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914AqHOiE
# V7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3EQ79P
# Ur8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3
# FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0gBE0w
# SzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcD
# CDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8G
# A1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1
# hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQl
# MjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUy
# MEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYIKwYB
# BQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlm
# aWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOCAgEA
# X4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVjJvic
# eW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGEndSp
# Z5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1CesufU211
# rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3ad4Xt
# m7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P8tHY
# IFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAodDW8
# HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb+H7D
# Ron9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D+mTm
# 8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN41LG
# XHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgHAPUv
# IdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgECAhMz
# AAAAVdndaSYo+fjiAAAAAABVMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jv
# c29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI1MTAyMzIw
# NDY0OVoXDTI2MTAyMjIwNDY0OVowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlv
# bnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMG
# A1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3Jp
# dHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC9uR+SHllIs/QwJRZp
# 9rD8pmhVm72JDHyvknCFm92tSLzpSMIIVA42NBqesjEYX2FEYhktBnnSAessL7h+
# lQQl9/m3ThXAHJYLb9tY66To2ZpOH0mk9kNwbM1H3lCWvKN8SO2X6DGPXbM08R0A
# M+mVV/O3xxhFYUHH8Vt9yHTyTo/2nuNfarWMU9tTFZgn7E7IYLVoqEMZjlv7zAvf
# 2/qoLQcUjH+/fL5t6n5oReigrxWh5Yr6zN9oWNejxhNy9DxQvizO70cVO5k2/q++
# gnsm76jlpOPnWymH7T4VdbfxOUv+sMF3mJrv2OyQu054dsOORuWOKXDN6BzG/2Lj
# 0XTlmtL/kQtkIJjVVqo7sQ4spVrHF0A7mjLW9vQHHRlFVfWbEWNjNrLYQLTnWTrI
# YkebnzLWh7YgpFr9IzX4FMax7q8c2LlDZ3lmehH0A4BQMPAkgipEjitnPYxKKeHX
# VatdMb26sXa6jJ3lV77yHF6z0AF4/Y9hAqVdhMDG91p5qcNND+/Cacz7JNxbOtWb
# zhnfxdUXDgbun9k1naexy+/q6u7YB69dzJXW3yFruJaaGGBNYE0GtWK4OVzeI+87
# PZJU9s96qHJj81fA1kICBzYfmk7O27ozBDEMiO17dcz8WQoHEeh9LZps1P/Qcb7F
# m0WpQkNrGBslrqU3XOHuymO5DwIDAQABo4IByzCCAccwHQYDVR0OBBYEFFYEXxBt
# 3AgD8Mi/qckWysHXrGW2MB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7ZPdsh
# MGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUy
# MENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFB1
# YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# ZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgG
# BmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAUh7hklR72pQpxZ5bKlyEHnx9cT9k
# ha/YPlc/n+T+0HssI30G+Y1JUpndV5yVAz3vzB8S+690xBJS/pjbRuggzwMrUrUh
# T1w/bUwbQTGIfFqqOuKR/apt+tciKngR/e/Zs1gpDELE3dJzOnVJfQfu6orYvk6F
# 8MSJd/XmKi7mGH4Q9pqqnj1zM1CkkM5H+98mCFRz+pyyUM+GgJmlnHxvY4O/LAZA
# 1fCqVuyYJLbi4aYSRDdQfklR43pz3XJqxVyFLvyuIyubpH1mkCI7ml80owZTYwub
# UDemnT3wNxsVMBz3keHpC+SH//bwX9d7ZswVvoMvtLDRk73m/SC/RlPIl/FL8sLF
# +tp4Qgj0VIU4oAwSnXM0VKza57QYaMG33IQQxTC/Gr0TEXPRpnNibyK8l99+khUO
# df/6tVFNhzEiRDIViyUiFiVYX1KMLDmvj2pqSMxE2Hxb07tpqiiVJVmV5BmMa3Qr
# wnMyXKnqGnaVtbpepHHZw4dtvEkPGYQ3OiEZTOIjXeUjaDYF/mqJt8Lhso1Gkmj2
# VsTwdRtjSomITy7dJTx4NBrJI9c4SEmPFEJDDA696NiYEbk/sJyRA0FKeeXXb4Up
# EqA+iPQy/7Pk4yGP3PYy2luccsCR6nSh1AKUTLIIb+5Hm0rmtbqZkfk6rnpRZLQ0
# jo1XUkZLsmuLqMUxggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAVdndaSYo+fjiAAAAAABV
# MA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZIhvcN
# AQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNjA5MzAxOTU2MTVa
# MC8GCSqGSIb3DQEJBDEiBCA8kXkYseG6mtVwGSUG69Nh/iEAsD/uvGZmJRUtCQwK
# 9DCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEINi5PJdkhmK7v33+/g9qqyZ5
# LMHGHSuqRiruxhhq+P7NMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAVdndaSYo+fjiAAAAAABVMIID
# XgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGkgd4w
# gdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQg
# VFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMVAB07
# VAGCZb+24FlXkQaOF+xXhw3qoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA7me9
# AjAiGA8yMDI2MDkzMDE2NTMyMloYDzIwMjYxMDAxMTY1MzIyWjB0MDoGCisGAQQB
# hFkKBAExLDAqMAoCBQDuZ70CAgEAMAcCAQACAlM4MAcCAQACAhNgMAoCBQDuaQ6C
# AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSCh
# CjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAC9kmoK7QT4LQJPxddjzMsSs
# QzjaqI3yminnwHXrzGHdyQakskUtBNwga3REZt1/GL6UBCMnTd9k+winraxuHffM
# tRUCBz+DlIl8kmSJlMgW05r2+76afnTsampLVb8a9QdjA+c9US0Ji71mG2a+CumY
# t/FLfp/eEjuDd2k8UFUiwt6h7xgNsYCP2fCVll1bJvY5oEk3kF/e4hQ6vJz6MdZG
# c7LuM8UT3R3eGhxv1yK3tHolImvaeC4Ie1aTY5h67Lxb0RgglmCMbt5+TnYprlK7
# 3XHcKwO9hLhAgeRn7VfmdenfIg9XUin3QPHjgVKJHzLBo0NfXumdfgBHojEFNZcw
# DQYJKoZIhvcNAQEBBQAEggIAneYXC2OI8CixCKLDhk+S2rzL64QXYDaTW70hFpUO
# 1xPULa96zNu/0Kalx97Zy4wzlN9SWfiyCAgSqvIrmP1Kd1SXWloNi8Ao3B84NhmZ
# IGyADCxl2OMMwZNKYNPeF/Ii+DjjRk6ydzZrapvC7Q6slRr60W+ErTOFPnlWjkj3
# sp7azwXqun+PJKycOLAzZ/xL4nB9HXCicEiKH0SEoGU5NTBxI4YOfxj4H/8MBA/H
# BCvSMxaGw8L1oNOB2phZusr+vxOz577mYDFleEFtPZQVnCzxD11rZ7ik3LaiikGY
# q6pLskeIeg9EmTOIHrsvFkBL//qE/BzG/Gztp6vHuFrpxNsSKdBuc+3fmTK/3/QT
# blVUEzYr6MHZdZVc71Nyd1iTS/+zpJgg2G7bkUhFtuoj0Tuw/J7tfedGm2VKgin2
# 9DSbGLDDPJYQLW/MoYAscHiWeW8hSv88Rp5SyWbieFlKUbdrEvaYy89I0gIHgt2d
# /tvT2J72MPItrsdog7loCkjVDyV9DCQms6maV7s/K6BCHMT8qP0oig6p64nJdb3t
# gQErhzeo+R42W73N6ckf18cpB/vTu93VofSs7L5y0U2uLRutRlvesM5IIh2zlONv
# 7nv6gXgsqgSvPNJqMJoHGTTp3bSLTrAHBxMAd3K2xsWolC6hQbtf9fgcl5gyDoYQ
# Cls=
# SIG # End signature block
