function Test-GPGInstallation {
    if (-not (Get-Command "gpg" -ErrorAction SilentlyContinue)) {
        Write-Error "GPG is not found on this system. Please install it first."
        exit 1
    }
}

function Get-GPGVersion {
    return (gpg --version | Select-Object -First 1).Split(" ")[2]
}

function New-GPGCommandFile($email, $name) {
    $tempFile = [System.IO.Path]::GetTempFileName()
    @"
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%commit
"@ | Out-File -Encoding ascii -FilePath $tempFile
    return $tempFile
}

function Invoke-GPGKeyGeneration($email, $name) {
    $gpgVersion = Get-GPGVersion
    $tempFile = New-GPGCommandFile $email $name

    Write-Host "Generating GPG key. Please follow any prompts..."
    if ([Version]$gpgVersion -ge [Version]"2.1.17") {
        gpg --batch --generate-key $tempFile
    } else {
        gpg --gen-key --batch $tempFile
    }

    Remove-Item $tempFile -Force
}

function Get-KeyIDByEmail($email) {
    return gpg --list-secret-keys --keyid-format LONG "$email" |
            Where-Object { $_ -match "sec\s+rsa4096/(\w+)" } |
            ForEach-Object { $matches[1] }
}

function Export-GPGPublicKey($keyId) {
    $publicKeyFile = "$env:USERPROFILE\public_key.asc"
    gpg --export -a $keyId > $publicKeyFile
    Write-Host "Public key saved to: $publicKeyFile"
    Write-Host "Please save the key from this location and then delete the file."
}

function Find-GPGKeyByEmail($email, $name) {
    $escapedEmail = [regex]::Escape($email)
    $existingKeys = gpg --list-keys --with-colons | Where-Object { $_ -like "*<${email}>*" }
    $pattern = "::([A-F0-9]{40})::.*?<${escapedEmail}>"

    foreach ($key in $existingKeys) {
        if ($key -match $pattern) {
            return @{
                UID = $matches[1].Trim()
                Email = $email
                Name = $name
            }
        }
    }

    return $null
}

function Set-GitGPGConfiguration($keyId) {
    $gpg_location = (Get-Command "gpg").Source
    git config --replace-all --global gpg.program $gpg_location
    git config --replace-all --global user.signingkey $keyId
    git config --global commit.gpgsign true
}

# Main Script Logic
Test-GPGInstallation

$name = Read-Host "Enter your name (e.g., John Doe):"
$email = Read-Host "Enter your verified email address for your GitHub account:"

$existingEntry = Find-GPGKeyByEmail $email $name

if ($existingEntry) {
    Write-Host "A GPG key associated with Name: $($existingEntry.Name) and email: $($existingEntry.Email) exists. UID: $($existingEntry.UID)"
    $choice = Read-Host "Do you want to generate a new one? (Yes/No)"
    if ($choice -ne "Yes") {
        Write-Output "GPG key already exists. Exiting..."
        exit
    }
}

Write-Output "Generating a new GPG key..."
Invoke-GPGKeyGeneration $email $name
$keyId = Get-KeyIDByEmail $email

if ($keyId) {
    Export-GPGPublicKey $keyId
    Set-GitGPGConfiguration $keyId
    Write-Output "GPG key has been generated and configured for Git."
} else {
    Write-Error "Failed to generate GPG key."
}
