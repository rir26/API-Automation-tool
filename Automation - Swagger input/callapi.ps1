###############################################################################
# callapi.ps1 – Dynamic GET-only contract testing driven by swagger.json
###############################################################################

# ─── USER SETTINGS ───────────────────────────────────────────────────────────
$swaggerFile = "swagger.json"          # OpenAPI spec
$logFile = "get_api_logs.json"     # per-call log
$overrideFile = "overrides.json"        # optional  { "dbId": "real-guid", ... }

# Supply a JWT here or export it first:  $env:API_BEARER_TOKEN = "<token>"
$bearerToken = ""
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

# Optional: raw request body support for POST/PATCH/PUT
$rawBodyFile = "raw-body.json"   # any text file; default name
if ($overrides.rawBodyFile) { $rawBodyFile = [string]$overrides.rawBodyFile }
$rawContentType = $null
if ($overrides.rawContentType) { $rawContentType = [string]$overrides.rawContentType }

Write-Host "`n--- Calling ALL GET APIs from Swagger with Dynamic Params ---`n"

# ─── HELPERS ─────────────────────────────────────────────────────────────────
function Resolve-Ref {
    param($swagger, $ref)
    # OpenAPI 3.0: #/components/schemas/Name or #/components/parameters/Name
    if ($ref -match '#/components/(?<section>schemas|parameters)/(?<name>.+)') {
        return $swagger.components.$($matches.section).$($matches.name)
    }
    # Swagger 2.0: #/definitions/Name or #/parameters/Name
    if ($ref -match '#/(?<section>definitions|parameters)/(?<name>.+)') {
        $section = $matches.section
        $name = $matches.name
        if ($section -eq 'definitions') {
            return $swagger.definitions.$name
        }
        elseif ($section -eq 'parameters') {
            return $swagger.parameters.$name
        }
    }
    return $null
}

function Make-SampleValue {
    param($schema)

    if ($schema.example) { return $schema.example }
    if ($schema.default) { return $schema.default }

    switch ($schema.type) {
        'string' { if ($schema.format -eq 'uuid') { return [guid]::NewGuid().Guid }; return 'sample' }
        'integer' { return 1 }
        'number' { return 1 }
        'boolean' { return $true }
        'array' { return @() }
        default { return 'sample' }
    }
}
function Apply-OverridesToBody {
    param(
        $obj,
        $overrides
    )
    if ($null -eq $obj) { return $null }
    $overrideNames = @()
    if ($overrides) { $overrideNames = $overrides.PSObject.Properties.Name }
    if ($obj -is [hashtable]) {
        foreach ($k in @($obj.Keys)) {
            if ($overrideNames -contains $k) { $obj[$k] = $overrides.$k }
        }
    }
    return $obj
}

function Build-SampleFromSchema {
    param(
        $schema,
        $swagger,
        [switch]$onlyRequired
    )

    if (-not $schema) { return $null }
    if ($schema.'$ref') { $schema = Resolve-Ref $swagger $schema.'$ref' }

    if ($schema.example) { return $schema.example }
    if ($schema.default) { return $schema.default }

    if ($schema.enum) { return $schema.enum[0] }

    switch ($schema.type) {
        'object' {
            $obj = @{}
            $props = @{}
            if ($schema.properties) { $props = $schema.properties.PSObject.Properties }

            $required = @()
            if ($schema.required) { $required = $schema.required }

            foreach ($p in $props) {
                $name = $p.Name
                if ($onlyRequired -and -not ($required -contains $name)) { continue }

                $propSchema = $p.Value
                if ($propSchema.'$ref') { $propSchema = Resolve-Ref $swagger $propSchema.'$ref' }

                $val = Build-SampleFromSchema $propSchema $swagger
                $obj[$name] = $val
            }

            # If required properties are missing (no properties declared), add minimal placeholders
            if (($required.Count -gt 0) -and ($obj.Keys.Count -lt $required.Count)) {
                foreach ($r in $required) {
                    if (-not $obj.ContainsKey($r)) { $obj[$r] = 'sample' }
                }
            }

            return $obj
        }

        'array' {
            $itemSchema = $schema.items
            $min = 1
            if ($schema.minItems) { $min = [int]$schema.minItems }
            $arr = @()
            for ($i = 0; $i -lt $min; $i++) {
                $arr += (Build-SampleFromSchema $itemSchema $swagger)
            }
            return $arr
        }

        'string' {
            if ($schema.format) {
                switch ($schema.format) {
                    'uuid' { return [guid]::NewGuid().Guid }
                    'date-time' { return (Get-Date).ToString('o') }
                    'email' { return 'sample@example.com' }
                    'uri' { return 'http://example.local/sample' }
                }
            }
            if ($schema.minLength) { return 'a' * [int]$schema.minLength }
            return Make-SampleValue $schema
        }

        'integer' { return Make-SampleValue $schema }
        'number' { return Make-SampleValue $schema }
        'boolean' { return Make-SampleValue $schema }
        default { return Make-SampleValue $schema }
    }
}

function Get-ParamDefinitions {
    param($operation, $swagger)
    $defs = @{ Path = @{}; Query = @{}; Header = @{} }
    if ($operation.parameters) {
        foreach ($p in $operation.parameters) {
            if ($p.'$ref') { $p = Resolve-Ref $swagger $p.'$ref' }
            switch ($p.in) {
                'path' { $defs.Path[$p.name] = $p }
                'query' { $defs.Query[$p.name] = $p }
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

    foreach ($opProp in $pathNode.PSObject.Properties) {
        $opName = $opProp.Name.ToLower()
        if ($opName -notin @('get', 'post', 'put', 'patch', 'delete')) { continue }

        $operation = $opProp.Value
        Write-Host "Processing endpoint: $($opName.ToUpper()) $template"

        $paramValues = @{}          # guarantees same value reused across param types
        $defs = Get-ParamDefinitions $operation $swagger

        # ── PATH PARAMETERS ──────────────────────────────────────────────────
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
                else { $v = 'sample' }
            }
            $paramValues[$n] = $v
            $path = $path -replace "\{$n\}", [string]$v
        }

        # ── QUERY PARAMETERS ───────────────────────────────────────────────
        $queryParts = @()
        foreach ($item in $defs.Query.GetEnumerator()) {
            $n = $item.Key
            $def = $item.Value
            $v = $null

            if ($paramValues.ContainsKey($n)) { $v = $paramValues[$n] }
            elseif ($overrides.$n) { $v = $overrides.$n }
            elseif ($def.required) { $v = Make-SampleValue $def.schema }

            if ($null -ne $v) {
                $queryParts += "$n=$([uri]::EscapeDataString([string]$v))"
            }
        }

        # ── COMPLETE URL ─────────────────────────────────────────────────
        $url = "$baseUrl$path"
        if ($queryParts) { $url += '?' + ($queryParts -join '&') }

        Write-Host "  Calling: $url"
        if ($contentTypeToSend) { Write-Host "  Content-Type: $contentTypeToSend" }
        if ($body) { Write-Host "  Request Body: $body" }
        $entry = @{
            method              = $opName.ToUpper()
            url                 = $url
            endpoint            = "${opName.ToUpper()} $template"
            success             = $false
            error               = $null
            response            = $null
            validation_passed   = $null
            validation_failures = @()
        }

        # Raw body override for write operations
        $body = $null
        $contentTypeToSend = $null
        if ($opName -in @('post', 'patch', 'put') -and (Test-Path $rawBodyFile)) {
            $body = Get-Content $rawBodyFile -Raw
            if ($rawContentType) { $contentTypeToSend = $rawContentType }
            elseif (-not $headers.ContainsKey('Content-Type')) { $contentTypeToSend = 'application/json' }
            if ($contentTypeToSend) { $headers['Content-Type'] = $contentTypeToSend }
            if (-not $headers.ContainsKey('Accept')) { $headers['Accept'] = 'application/json' }
        }

        # Build request body from spec if no raw override and operation is write method
        if (-not $body -and $opName -in @('post', 'patch', 'put') -and $operation.requestBody) {
            $contentProps = $operation.requestBody.content.PSObject.Properties
            $preferred = @('application/json', 'application/merge-patch+json', 'application/json-patch+json', 'application/x-www-form-urlencoded', 'multipart/form-data', 'text/plain')
            $availableTypes = $contentProps | ForEach-Object { $_.Name }
            $contentTypeToSend = ($preferred | Where-Object { $_ -in $availableTypes } | Select-Object -First 1)
            if (-not $contentTypeToSend) { $contentTypeToSend = ($availableTypes | Select-Object -First 1) }

            if ($contentTypeToSend) {
                $ctNode = $operation.requestBody.content.$contentTypeToSend
                $bObj = $null
                if ($ctNode.example) { $bObj = $ctNode.example }
                elseif ($ctNode.schema) { $bObj = Build-SampleFromSchema $ctNode.schema $swagger }

                $bObj = Apply-OverridesToBody $bObj $overrides

                if ($bObj -ne $null) {
                    switch ($contentTypeToSend) {
                        'application/json' { $body = $bObj | ConvertTo-Json -Depth 10 }
                        'application/merge-patch+json' { $body = $bObj | ConvertTo-Json -Depth 10 }
                        'application/json-patch+json' {
                            if ($bObj -is [System.Collections.IEnumerable]) { $body = $bObj | ConvertTo-Json -Depth 10 }
                            else { $body = @(@{ op = 'replace'; path = '/'; value = $bObj }) | ConvertTo-Json -Depth 10 }
                        }
                        'application/x-www-form-urlencoded' {
                            # Build a name=value body string from object properties
                            if ($bObj -is [hashtable]) {
                                $pairs = @()
                                foreach ($k in $bObj.Keys) { $pairs += ("$k=" + [uri]::EscapeDataString([string]$bObj[$k])) }
                                $body = ($pairs -join '&')
                            }
                            else {
                                $body = ''
                            }
                        }
                        'multipart/form-data' {
                            # For multipart, PowerShell expects a hashtable for -Form
                            if ($bObj -is [hashtable]) {
                                $body = $bObj
                            }
                            else {
                                $body = @{}
                            }
                        }
                        'text/plain' { $body = [string]$bObj }
                        default { $body = ($bObj | ConvertTo-Json -Depth 10) }
                    }
                }
                $headers['Content-Type'] = $contentTypeToSend
                if (-not $headers.ContainsKey('Accept')) { $headers['Accept'] = $contentTypeToSend }
            }
        }
        elseif (-not $body -and $opName -in @('post', 'patch', 'put') -and $operation.parameters) {
            # OpenAPI 2.0: body parameter + consumes
            $bodyParam = $null
            foreach ($prm in $operation.parameters) {
                if ($prm.'$ref') { $prm = Resolve-Ref $swagger $prm.'$ref' }
                if ($prm.in -eq 'body') { $bodyParam = $prm; break }
            }
            if ($bodyParam) {
                $consumes = @(); if ($operation.consumes) { $consumes = $operation.consumes }
                $preferred = @('application/json', 'text/json', 'application/*+json', 'application/x-www-form-urlencoded', 'multipart/form-data', 'text/plain')
                $contentTypeToSend = ($preferred | Where-Object { $_ -in $consumes } | Select-Object -First 1)
                if (-not $contentTypeToSend -and $consumes.Count -gt 0) { $contentTypeToSend = $consumes[0] }

                $schema = $bodyParam.schema
                $bObj = $null
                if ($schema) { $bObj = Build-SampleFromSchema $schema $swagger }

                $bObj = Apply-OverridesToBody $bObj $overrides

                if ($bObj -ne $null) {
                    switch ($contentTypeToSend) {
                        'application/json' { $body = $bObj | ConvertTo-Json -Depth 10 }
                        'text/json' { $body = $bObj | ConvertTo-Json -Depth 10 }
                        'application/*+json' { $body = $bObj | ConvertTo-Json -Depth 10 }
                        'application/x-www-form-urlencoded' {
                            if ($bObj -is [hashtable]) { $pairs = @(); foreach ($k in $bObj.Keys) { $pairs += ("$k=" + [uri]::EscapeDataString([string]$bObj[$k])) }; $body = ($pairs -join '&') } else { $body = '' }
                        }
                        'multipart/form-data' { if ($bObj -is [hashtable]) { $body = $bObj } else { $body = @{} } }
                        'text/plain' { $body = [string]$bObj }
                        default { $body = ($bObj | ConvertTo-Json -Depth 10) }
                    }
                }

                if ($contentTypeToSend) {
                    $headers['Content-Type'] = $contentTypeToSend
                    if (-not $headers.ContainsKey('Accept')) { $headers['Accept'] = 'application/json' }
                }
            }
        }

        # ── API CALL + VALIDATION ────────────────────────────────────────
        try {
            if ($body) {
                if ($contentTypeToSend -eq 'multipart/form-data') {
                    # Use -Form for multipart bodies
                    $response = Invoke-RestMethod -Method $opName.ToUpper() -Uri $url -Headers $headers -Form $body
                }
                elseif ($contentTypeToSend) {
                    $response = Invoke-RestMethod -Method $opName.ToUpper() -Uri $url -Headers $headers -Body $body -ContentType $contentTypeToSend
                }
                else {
                    $response = Invoke-RestMethod -Method $opName.ToUpper() -Uri $url -Headers $headers -Body $body
                }
            }
            else {
                $response = Invoke-RestMethod -Method $opName.ToUpper() -Uri $url -Headers $headers
            }

            $entry.success = $true
            $entry.response = $response
            Write-Host "  API call successful"

            # Choose a success response code to validate (prefer 200/201/204)
            $respCodes = $operation.responses.PSObject.Properties | ForEach-Object { $_.Name }
            $successCode = ($respCodes | Where-Object { $_ -in @('200', '201', '204') } | Select-Object -First 1)
            if (-not $successCode) { $successCode = ($respCodes | Select-Object -First 1) }

            if ($successCode -eq '204') {
                $entry.validation_passed = $true
                Write-Host "  No content (204) - skipping JSON validation"
            }
            else {
                $schemaNode = $null
                if ($operation.responses.$successCode -and $operation.responses.$successCode.content) {
                    $schemaNode = $operation.responses.$successCode.content.'application/json'.schema
                }

                if ($schemaNode) {
                    $v = Validate-ObjectSchema $schemaNode $response $swagger
                    $entry.validation_passed = $v.success
                    $entry.validation_failures = $v.failures

                    $statusText = if ($v.success) { 'PASSED' } else { 'FAILED' }
                    $statusColor = if ($v.success) { 'Green' } else { 'Red' }
                    Write-Host ("  Swagger validation: {0}" -f $statusText) -ForegroundColor $statusColor

                    if (-not $v.success) { foreach ($f in $v.failures) { Write-Host "    $f" } }
                }
                else {
                    $entry.validation_passed = $true
                    Write-Host "  No JSON schema for $successCode response"
                }
            }
        }
        catch {
            $entry.error = $_.Exception.Message
            # Try to read error response body for diagnostics
            try {
                if ($_.Exception.Response) {
                    $respStream = $_.Exception.Response.GetResponseStream()
                    if ($respStream) {
                        $reader = New-Object System.IO.StreamReader($respStream)
                        $errBody = $reader.ReadToEnd()
                        if ($errBody) { $entry.response = $errBody }
                    }
                }
            }
            catch {}
            Write-Host "  API call failed: $($entry.error)" -ForegroundColor Red
            if ($entry.response) { Write-Host "  Error body: $($entry.response)" }
            $entry.validation_passed = $false
        }

        $results += $entry
        Write-Host ""
    }
}

# ─── LOG & SUMMARY ───────────────────────────────────────────────────────────
$results | ConvertTo-Json -Depth 10 | Set-Content $logFile -Encoding UTF8
Write-Host "API call logs saved to: $logFile"

$total = $results.Count
$successCnt = ($results | Where-Object { $_.success }).Count
$swaggerPass = ($results | Where-Object { $_.validation_passed }).Count
$swaggerFail = ($results | Where-Object { $_.success -and -not $_.validation_passed }).Count

$successRate = if ($total) { [math]::Round($successCnt / $total * 100, 1) } else { 0 }
$valRate = if ($successCnt) { [math]::Round($swaggerPass / $successCnt * 100, 1) } else { 0 }

Write-Host "--- SUMMARY ---------------------------------------------------"
Write-Host "Total endpoints tested  : $total"
Write-Host "Successful API calls    : $successCnt"
Write-Host "Failed API calls        : $($total - $successCnt)"
Write-Host "Swagger validation pass : $swaggerPass"
Write-Host "Swagger validation fail : $swaggerFail"
Write-Host "API Success Rate        : $successRate%"
Write-Host "Swagger Validation Rate : $valRate%"
