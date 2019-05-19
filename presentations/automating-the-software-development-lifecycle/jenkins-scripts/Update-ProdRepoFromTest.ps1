<#
.NOTES
    Written by Paul Broadwwith (paul@pauby.com) October 2018
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]
    $ProdRepo,

    [Parameter(Mandatory)]
    [string]
    $ProdRepoApiKey,

    [Parameter(Mandatory)]
    [string]
    $TestRepo
)

. .\ConvertTo-ChocoObject.ps1

# get all of the packages from the test repo
$testPkgs = choco.exe list --source $TestRepo | Select-Object -Skip 1 | Select-Object -SkipLast 1 | ConvertTo-ChocoObject
$prodPkgs = choco.exe list --source $ProdRepo | Select-Object -Skip 1 | Select-Object -SkipLast 1 | ConvertTo-ChocoObject
$tempPath = Join-Path -Path $env:TEMP -ChildPath ([GUID]::NewGuid()).GUID
if ($null -eq $testPkgs) {
    Write-Verbose "Test repository appears to be empty. Nothing to push to production."
}
elseif ($null -eq $prodPkgs) {
    $pkgs = $testPkgs
}
else {
    $pkgs = Compare-Object -ReferenceObject $testpkgs -DifferenceObject $prodpkgs -Property name, version | Where-Object SideIndicator -eq '<='
}

$pkgs | ForEach-Object {
    Write-Verbose "Downloading package '$($_.name)' to '$tempPath'."
    choco.exe download $_.name --no-progress --output-directory=$tempPath --source=$TestRepo --force

    if ($LASTEXITCODE -eq 0) {
        $pkgPath = (Get-Item -Path (Join-Path -Path $tempPath -ChildPath "$($_.name)*.nupkg")).FullName

        # #######################
        # INSERT CODE HERE TO TEST YOUR PACKAGE
        # #######################

        $failed = (Invoke-Pester -Script @{ Path = '.\Test-Package.ps1'; Parameters = @{ Package = $_.name; Source = $TestRepo } } -Passthru).FailedCount

        # If package testing is successful ...
        if (-not $failed) {
            Write-Verbose "Pushing downloaded package '$(Split-Path -Path $pkgPath -Leaf)' to production repository '$ProdRepo'."
            choco.exe push $pkgPath --source=$ProdRepo --api-key=$ProdRepoApiKey --force

            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Pushed package successfully."
            }
            else {
                Write-Verbose "Could not push package."
            }
        }
        else {
            Write-Verbose "Package testing failed."
        }

        Remove-Item -Path $pkgPath -Force
    }
    else {
        Write-Verbose "Could not download package."
    }
}