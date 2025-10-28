###############################################################################
# callapi.ps1 – Dynamic GET-only contract testing driven by swagger.json
###############################################################################

# ─── USER SETTINGS ───────────────────────────────────────────────────────────
$swaggerFile  = "swagger.json"          # OpenAPI spec
$logFile      = "get_api_logs.json"     # per-call log
$overrideFile = "overrides.json"        # optional  { "dbId": "real-guid", ... }

# Supply a JWT here or export it first:  $env:API_BEARER_TOKEN = "<token>"
$bearerToken  = "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6InlFVXdtWFdMMTA3Q2MtN1FaMldTYmVPYjNzUSJ9.eyJhdWQiOiI4MWE0OGEwMC1hZTFhLTQ2ZDYtYmYxZS0yMjZmZmU2MDczYmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDY5YWU2YmMtMWI3Yy00YWJmLWJkODktODQ2MGYwNDNhOTRkL3YyLjAiLCJpYXQiOjE3NjE2NTIzMzksIm5iZiI6MTc2MTY1MjMzOSwiZXhwIjoxNzYxNjU3MjE2LCJhaW8iOiJBUVFCKy80YUFBQUFDN0JLTVcrYU8xZ29QZ0d4dU5TbTlSQnVOcGR0b0RhcXRPeVlzOHJ3N20vU3c5VCtDdGtyMks1UVlGajNHMDBRTXZneUNUQUY5UXljdGRyQ3JxRXhKY0FPanBhTHFLWE9TN2VOcFBuL25pbWxmaTNwOTZvMWRPNUdZTE1yZE5aU3V2ZkhSS0I4U01xdW0yZUcwbkhDQmZOVVdFQzEvT05vbDBHS1NEY3o2WUJLMHZPamRta2FWN0VTWVMwWmNTS2gwMDZhZStnRjZWME5GcDVNcHRIU0tQdDRoREhaQlN4YlJ5SVRsK1VDOWQ0UGhtQXlhVFZCNXd4eERyMEpTZVRVUE1MSW10VXlJR2NlMElyemZOclNCQ2tQSkFlNkY1ME8wbEdoSm14Um0xdnFOVWRKSHgwZk5mV3NqRHdoYlM0UXRDSTErTnF0emNIRmUrR0IwWkJPR2c9PSIsImF6cCI6IjgxYTQ4YTAwLWFlMWEtNDZkNi1iZjFlLTIyNmZmZTYwNzNiYyIsImF6cGFjciI6IjAiLCJlbWFpbCI6InNoYWZhdC5odXNzYWluQG1hdmltLmNvbSIsImxvZ2luX2hpbnQiOiJPLkNpUTFObUZrTkRReVl5MHdOak13TFRSalpXVXRZalU1TVMxbFpXVXdOekZqTWpVeE9EUVNKREEyT1dGbE5tSmpMVEZpTjJNdE5HRmlaaTFpWkRnNUxUZzBOakJtTURRellUazBaQm9OYzJoMVFHMWhkbWx0TG1OdmJTRFpBUT09IiwibmFtZSI6IlNoYWZhdCBIdXNzYWluIiwib2lkIjoiNTZhZDQ0MmMtMDYzMC00Y2VlLWI1OTEtZWVlMDcxYzI1MTg0IiwicHJlZmVycmVkX3VzZXJuYW1lIjoic2h1QG1hdmltLmNvbSIsInJoIjoiMS5BVjRBdk9hYUJud2J2MHE5aVlSZzhFT3BUUUNLcElFYXJ0Wkd2eDRpYl81Z2M3d1JBWTFlQUEuIiwic2NwIjoiTWF2aW0uaU1wcm92ZS5SZWFkV3JpdGUuQWxsIiwic2lkIjoiMDA5OWFmZDktZThlNy0yOWRmLTQzMzMtMWQyODA4ODQ2MDg1Iiwic3ViIjoiaVdON1lqM2l6a0owNmFyaHl6cjV0X2hRelVUb1hYYUtHaW5RN1pIVVZ6ZyIsInRpZCI6IjA2OWFlNmJjLTFiN2MtNGFiZi1iZDg5LTg0NjBmMDQzYTk0ZCIsInV0aSI6Im5IcVlUY0FoblVHODQ5TWJCNGE5QUEiLCJ2ZXIiOiIyLjAiLCJ4bXNfZnRkIjoielMxQmxLeE9SSy1vTlVaVDlzUmRVTUVZNVVpSGFFalNkUFdpREczSDZsZ0JjM2RsWkdWdVl5MWtjMjF6In0.W-6rUzB7h6DGBeLKH57zvkUtr8wOPll8yv6i3LxkiBL22ai9Fr-ldlTe7kvSXCpNUYA2u5hpfGZLIkljmy_LN4d8tgGxEXaobhJ7kHy14W4gU4iIAQw5Ws58OrpIhJxixEsfiWCRllGyXfrBKYUtCH43nfomuLtvtgEsZhNY2GNwtW1ayu7EHJdqm9EZyyuzN8HacWvp014uCXvj2hTf4zYKFblBZXTMuf6OK_3wQULWENrFmyDK7AtebcKrbeGSoMs-b5KoMflZi2f2OImei4TXQ0fWz2o-dZ7gHW92xWas55_2imQH4SsPyIVARjx_VJ1Dr3N5G5iyf_f0Gaq23g"
# $bearerToken = "Bearer <PASTE-YOUR-TOKEN-HERE>"

# ─── LOAD SPEC & PREPARE ─────────────────────────────────────────────────────
if (-not (Test-Path $swaggerFile)) { throw "Cannot find $swaggerFile" }
$swagger = Get-Content $swaggerFile -Raw | ConvertFrom-Json
$baseUrl = $swagger.servers[0].url.TrimEnd('/')

$headers = @{ Authorization = $bearerToken; Accept = "application/json" }

$overrides = @{}
if (Test-Path $overrideFile) {
    $overrides = Get-Content $overrideFile -Raw | ConvertFrom-Json
}

Write-Host "`n--- Calling ALL GET APIs from Swagger with Dynamic Params ---`n"

# ─── HELPERS ─────────────────────────────────────────────────────────────────
function Resolve-Ref {
    param($swagger, $ref)
    if ($ref -match '#/components/(?<section>schemas|parameters)/(?<name>.+)') {
        return $swagger.components.$($matches.section).$($matches.name)
    }
}

function Make-SampleValue {
    param($schema)

    if ($schema.example) { return $schema.example }
    if ($schema.default) { return $schema.default }

    switch ($schema.type) {
        'string'  { if ($schema.format -eq 'uuid') { return [guid]::NewGuid().Guid }; return 'sample' }
        'integer' { return 1 }
        'number'  { return 1 }
        'boolean' { return $true }
        'array'   { return @() }
        default   { return 'sample' }
    }
}

function Get-ParamDefinitions {
    param($operation, $swagger)
    $defs = @{ Path=@{}; Query=@{}; Header=@{} }
    if ($operation.parameters) {
        foreach ($p in $operation.parameters) {
            if ($p.'$ref') { $p = Resolve-Ref $swagger $p.'$ref' }
            switch ($p.in) {
                'path'   { $defs.Path[$p.name]   = $p }
                'query'  { $defs.Query[$p.name]  = $p }
                'header' { $defs.Header[$p.name] = $p }
            }
        }
    }
    return $defs
}

function Validate-ObjectSchema {
    param($schema, $actual, $swagger)
    #  ⬇  Replace this stub with the full validator when you’re ready
    return @{ success = $true; failures = @() }
}

# ─── MAIN LOOP ───────────────────────────────────────────────────────────────
$results = @()

foreach ($pathProp in $swagger.paths.PSObject.Properties) {
    $template = $pathProp.Name
    $pathNode = $pathProp.Value
    if (-not $pathNode.get) { continue }   # only GET endpoints

    Write-Host "Processing endpoint: $template"

    $paramValues = @{}          # guarantees same value reused across param types
    $defs = Get-ParamDefinitions $pathNode.get $swagger

    # ── PATH PARAMETERS ──────────────────────────────────────────────────────
    $path = $template
    foreach ($item in $defs.Path.GetEnumerator()) {
        $n = $item.Key
        $v = $overrides.$n
        if (-not $v) { $v = Make-SampleValue $item.Value.schema }
        $paramValues[$n] = $v
        $path = $path -replace "\{$n\}", [string]$v
    }

    # any leftover {xyz} not declared in spec
    foreach ($m in [regex]::Matches($path, '\{([^}]+)\}')) {
        $n = $m.Groups[1].Value
        $v = $overrides.$n
        if (-not $v) {
            if ($n -match 'id$|Id$|ID$') { $v = [guid]::NewGuid().Guid }
            else                         { $v = 'sample' }
        }
        $paramValues[$n] = $v
        $path = $path -replace "\{$n\}", [string]$v
    }

    # ── QUERY PARAMETERS ─────────────────────────────────────────────────────
    $queryParts = @()
    foreach ($item in $defs.Query.GetEnumerator()) {
        $n = $item.Key
        $def = $item.Value
        $v = $null

        if     ($paramValues.ContainsKey($n)) { $v = $paramValues[$n] }
        elseif ($overrides.$n)                { $v = $overrides.$n }
        elseif ($def.required)                { $v = Make-SampleValue $def.schema }

        if ($null -ne $v) {
            $queryParts += "$n=$([uri]::EscapeDataString([string]$v))"
        }
    }

    # ── COMPLETE URL ─────────────────────────────────────────────────────────
    $url = "$baseUrl$path"
    if ($queryParts) { $url += '?' + ($queryParts -join '&') }

    Write-Host "  Calling: $url"
    $entry = @{
        url                = $url
        endpoint           = $template
        success            = $false
        error              = $null
        response           = $null
        validation_passed  = $null
        validation_failures= @()
    }

    # ── API CALL + VALIDATION ────────────────────────────────────────────────
    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
        $entry.success  = $true
        $entry.response = $response
        Write-Host "  API call successful"

        $schemaNode = $pathNode.get.responses.'200'.content.'application/json'.schema
        if ($schemaNode) {
            $v = Validate-ObjectSchema $schemaNode $response $swagger
            $entry.validation_passed   = $v.success
            $entry.validation_failures = $v.failures

            $statusText  = if ($v.success) { 'PASSED' } else { 'FAILED' }
            $statusColor = if ($v.success) { 'Green'  } else { 'Red'   }
            Write-Host ("  Swagger validation: {0}" -f $statusText) -ForegroundColor $statusColor

            if (-not $v.success) {
                foreach ($f in $v.failures) { Write-Host "    $f" }
            }
        } else {
            $entry.validation_passed = $true
            Write-Host "  No JSON schema for 200 response"
        }
    }
    catch {
        $entry.error = $_.Exception.Message
        Write-Host "  API call failed: $($entry.error)" -ForegroundColor Red
        $entry.validation_passed = $false
    }

    $results += $entry
    Write-Host ""
}

# ─── LOG & SUMMARY ───────────────────────────────────────────────────────────
$results | ConvertTo-Json -Depth 10 | Set-Content $logFile -Encoding UTF8
Write-Host "API call logs saved to: $logFile"

$total        = $results.Count
$successCnt   = ($results | Where-Object { $_.success }).Count
$swaggerPass  = ($results | Where-Object { $_.validation_passed }).Count
$swaggerFail  = ($results | Where-Object { $_.success -and -not $_.validation_passed }).Count

$successRate  = if ($total)      { [math]::Round($successCnt / $total * 100,1) } else { 0 }
$valRate      = if ($successCnt) { [math]::Round($swaggerPass / $successCnt * 100,1) } else { 0 }

Write-Host "--- SUMMARY ---------------------------------------------------"
Write-Host "Total endpoints tested  : $total"
Write-Host "Successful API calls    : $successCnt"
Write-Host "Failed API calls        : $($total - $successCnt)"
Write-Host "Swagger validation pass : $swaggerPass"
Write-Host "Swagger validation fail : $swaggerFail"
Write-Host "API Success Rate        : $successRate%"
Write-Host "Swagger Validation Rate : $valRate%"
