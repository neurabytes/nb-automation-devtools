# Ensure GPG is installed
if (-not (Get-Command "gpg" -ErrorAction SilentlyContinue)) {
    Write-Error "GPG is not found on this system. Please install it first."
    exit 1
}

function GenerateGPGKey($email, $name) {
    $gpgVersion = (gpg --version | Select-Object -First 1).Split(" ")[2]

    $gpgCmd = @"
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%commit
"@
    # Use a temporary file for GPG commands
    $tempFile = [System.IO.Path]::GetTempFileName()
    $gpgCmd | Out-File -Encoding ascii -FilePath $tempFile

    Write-Host "Generating GPG key. Please follow any prompts..."
    if ([Version]$gpgVersion -ge [Version]"2.1.17") {
        gpg --batch --generate-key $tempFile
    } else {
        gpg --gen-key --batch $tempFile
    }

    # Retrieve keyId for the given email address
    $keyId = gpg --list-secret-keys --keyid-format LONG "$email" | Where-Object { $_ -match "sec\s+rsa4096/(\w+)" } | ForEach-Object { $matches[1] }

    $publicKeyFile = "$env:USERPROFILE\public_key.asc"

    gpg --export -a $keyId > $publicKeyFile

    Write-Host "Public key saved to: $publicKeyFile"
    Write-Host "Please save the key from this location and then delete the file."


    Remove-Item $tempFile -Force

    # Return the keyId, email, and name as a custom object
    return [PSCustomObject]@{
        'KeyID' = $keyId
        'Email' = $email
        'Name'  = $name
    }
}


$name = Read-Host "Enter your name (e.g., John Doe):"
$email = Read-Host "Enter your verified email address for your GitHub account:"

# Check for existing GPG keys with the provided email
# TODO - This logic is not working and new keys are always generated
$existingKeys = gpg --list-keys --with-colons | where { $_ -like "*<${email}>*" }

$existingEntry = $null

foreach ($key in $existingKeys) {
    if ($key -match "uid:(.*?):<(${email})>") {
        $existingEntry = @{
            Name = $matches[1].Trim()
            Email = $matches[2]
        }
        break
    }
}

$newKey = $null

if ($existingEntry) {
    Write-Host "A GPG key associated with name: $($existingEntry.Name) and email: $($existingEntry.Email) exists."
    $choice = Read-Host "Do you want to generate a new one? (Yes/No)"
    if ($choice -eq "Yes") {
        Write-Output "Generating a new GPG key, even when a key exists..."
        $newKey = GenerateGPGKey $email $name
    }
    else
    {
        Write-Output "GPG key already exists. Exiting..."
    }
} else {
    Write-Output "Key does not exists. Generating a new GPG key..."
    $newKey = GenerateGPGKey $email $name
}

# Check if a key was generated successfully
if ($null -ne $newKey.KeyID -and $newKey.KeyID -ne "") {
    # The key was generated
    $gpg_location = where.exe gpg

    git config --global gpg.program $gpg_location
    git config --global user.signingkey $newKey.KeyID
    git config --global commit.gpgsign true
}
