@echo off
setlocal

set "BASEDIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference = 'Stop'; ^
$baseDir = [IO.Path]::GetFullPath('%BASEDIR%'); ^
$privateKey = Join-Path $baseDir 'pineapple_key'; ^
$publicKey  = $privateKey + '.pub'; ^
$authFile   = Join-Path $baseDir 'authorized_keys'; ^
$authPub    = Join-Path $baseDir 'authorized_keys_pub'; ^
$magicKey   = Join-Path $baseDir 'magic_key'; ^
if (Test-Path $privateKey) { Remove-Item $privateKey -Force }; ^
if (Test-Path $publicKey)  { Remove-Item $publicKey  -Force }; ^
if (Test-Path $authFile)   { Remove-Item $authFile   -Force }; ^
if (Test-Path $authPub)    { Remove-Item $authPub    -Force }; ^
if (Test-Path $magicKey)   { Remove-Item $magicKey   -Force }; ^
ssh-keygen -t rsa -b 2048 -f $privateKey; ^
if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed' }; ^
$pubText = Get-Content $publicKey -Raw; ^
Set-Content -Path $authFile -Value $pubText -NoNewline; ^
Set-Content -Path $authPub  -Value $pubText -NoNewline; ^
$privB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($privateKey)); ^
Set-Content -Path $magicKey -Value $privB64 -NoNewline; ^
Write-Host ''; ^
Write-Host 'Created files:'; ^
Write-Host $privateKey; ^
Write-Host $publicKey; ^
Write-Host $authFile; ^
Write-Host $authPub; ^
Write-Host $magicKey; ^
Write-Host ''; ^
Write-Host 'Use authorized_keys on the Pineapple at /root/.ssh/authorized_keys'; ^
Write-Host 'Use magic_key as the Base64 private key value in your PowerShell script.'"

pause