# Shared by run.ps1 and web.ps1.

function Get-Flutter {
  $onPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  if (Test-Path 'C:\flutter\bin\flutter.bat') { return 'C:\flutter\bin\flutter.bat' }
  throw 'Flutter not found. Put it on PATH or install it at C:\flutter.'
}

# Keys live in tools/keys.local.ps1, which is gitignored. The repository is
# public: no key is ever committed. Copy keys.example.ps1 to start.
function Get-DartDefines {
  $local = Join-Path $PSScriptRoot 'keys.local.ps1'
  if (Test-Path $local) { . $local }

  $names = @(
    'GEMINI_API_KEY',
    'TWILIO_ACCOUNT_SID',
    'TWILIO_AUTH_TOKEN',
    'TWILIO_WHATSAPP_FROM'
  )
  $defines = @()
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) { $defines += "--dart-define=$name=$value" }
  }
  return $defines
}
