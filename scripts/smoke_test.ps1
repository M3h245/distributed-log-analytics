param(
    [string]$ProducerBaseUrl = "http://localhost:8001",
    [string]$ApiBaseUrl = "http://localhost:8002"
)

$ErrorActionPreference = "Stop"

Write-Host "1) Send test event to producer..."
$sendResponse = Invoke-RestMethod -Uri "$ProducerBaseUrl/send?message=ci-smoke-event" -Method Get
if ($sendResponse.status -ne "sent") {
    throw "Producer did not return status=sent"
}

Write-Host "2) Wait for processor to persist event..."
Start-Sleep -Seconds 2

Write-Host "3) Fetch logs from API..."
$logsResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/logs?limit=20" -Method Get
if (-not $logsResponse.logs) {
    throw "No logs returned from API"
}

$matched = $logsResponse.logs | Where-Object { $_.message -eq "ci-smoke-event" }
if (-not $matched) {
    throw "Smoke event was not found in API logs"
}

Write-Host "Smoke test passed."
