# Define the list of Chocolatey packages for which you want to retrieve dependencies
$tools = @{
    'git' = '2.42.0'
    'intellijidea-community' = '2023.2.3'
    'meld' = '3.22.0'
    'winscp' = '6.1.2'
    'terraform' = '1.6.2'
    'openjdk' = '21.0.1'
    'maven' = '3.9.5'
    'nodejs' = '21.1.0'
    'scala' = '2.11.4'
    'postman' = '10.18.10'
}

# Initialize an empty hash table to store dependencies
$dependencies = @{}

# Loop through each package and retrieve its dependencies
foreach ($tool in $tools.GetEnumerator()) {
    $packageInfo = choco info $tool.Name -r

    Write-Host "Checking $($tool.Name)"
    if ($packageInfo -match "Dependencies:\s*(.+)") {
        $dependencyString = $Matches[1]
        $packageDependencies = $dependencyString -split ', ' | ForEach-Object { $_.Trim() }

        foreach ($dependency in $packageDependencies) {
            # Add the dependency to the hash table with a value of 1
            # We use 1 as a placeholder since we're only interested in unique dependencies
            $dependencies[$dependency] = 1
        }
    }
}

# Convert the hash table to a list of unique dependencies
$uniqueDependencies = $dependencies.Keys

# Display the combined list of unique dependencies
Write-Host "Combined List of Dependencies:"
$uniqueDependencies | Sort-Object | ForEach-Object {
    Write-Host $_
}
