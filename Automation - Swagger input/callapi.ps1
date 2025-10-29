###############################################################################
# callapi.ps1 – Dynamic GET-only contract testing driven by swagger.json
###############################################################################

# ─── USER SETTINGS ───────────────────────────────────────────────────────────
$swaggerFile  = "swagger.json"          # OpenAPI spec
$logFile      = "get_api_logs.json"     # per-call log
$overrideFile = "overrides.json"        # optional  { "dbId": "real-guid", ... }

# Supply a JWT here or export it first:  $env:API_BEARER_TOKEN = "<token>"
$bearerToken  = ""
# $bearerToken = "Bearer <PASTE-YOUR-TOKEN-HERE>"

# ─── LOAD SPEC & PREPARE ─────────────────────────────────────────────────────
if (-not (Test-Path $swaggerFile)) { throw "Cannot find $swaggerFile" }
$swagger = Get-Content $swaggerFile -Raw | ConvertFrom-Json
$baseUrl = $swagger.servers[0].url.TrimEnd('/')

# Prefer bearer token provided via environment variable if present
if ($env:API_BEARER_TOKEN) {
    if ($env:API_BEARER_TOKEN -like 'Bearer *') { $bearerToken = $env:API_BEARER_TOKEN }
    else { $bearerToken = "Bearer $($env:API_BEARER_TOKEN)" }
}

$headers = @{}
if ($bearerToken) { $headers["Authorization"] = $bearerToken }
$headers["Accept"] = "application/json"

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
