param(
    [ValidateSet('Development', 'Production')]
    [string]$Environment = 'Development'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$profile = if ($Environment -eq 'Production') { 'environment.production.lua' } else { 'environment.development.lua' }
$files = @{
    'environment.lua' = $profile
    'config.ini' = 'config.example.ini'
}
foreach ($name in $files.Keys) {
    $target = Join-Path $root $name
    if (Test-Path -LiteralPath $target) {
        Write-Host "Preservado: $name (ja existe)."
    } else {
        Copy-Item -LiteralPath (Join-Path $root $files[$name]) -Destination $target
        Write-Host "Criado: $name a partir de $($files[$name])."
    }
}
Write-Host 'Configuracao pronta. Consulte docs/trabalho-em-equipe.md para recursos, compilacao e fluxo Git.'
