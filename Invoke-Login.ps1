[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $UUID,
    [Parameter(Mandatory, Position = 1)]
    [string]
    $Password,
    [Parameter(Position = 2)]
    [ValidateSet('cmcc', 'telecom', 'unicom')]
    [string]
    $Provider
)

function Get-ResponseJson {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebResponseObject]$Response
    )

    Process { $Response.Content.Substring($Response.Content.IndexOf('{')).Trim().TrimEnd(')') }
}

$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0'

if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
    $ssid = (Get-NetConnectionProfile -InterfaceAlias 'WLAN*').Name
} else {
    if (Get-Command 'iwgetid') {
        $ssid = iwgetid -r
    }
}

$isDorm = $ssid -and $ssid -cne 'seu-wlan'

if ($isDorm) {
    $serverHost = 'http://10.80.128.2/'
    $serverHostAlt = 'http://10.80.128.2:801/'
    Write-Debug 'Dormitory environment detected.'
} else {
    $serverHost = 'https://w.seu.edu.cn/'
    $serverHostAlt = 'https://w.seu.edu.cn:801/'
    Write-Debug 'Non-dormitory environment detected.'
}

$headers = @{'DHT' = '1'; 'Referer' = $serverHost }

$urlQuery = $serverHost + 'drcom/chkstatus?callback=dr1000'
Write-Debug "Connecting to $($urlQuery)"

try {
    Invoke-WebRequest -URI $urlQuery -Headers $headers -UserAgent $userAgent -SessionVariable 'session' -ErrorAction Stop |
    Get-ResponseJson | ConvertFrom-Json -OutVariable 'status' | Write-Debug

    if ($status.result -eq 1) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Currently logged in as $($status.uid) $($status.NID)." -ForegroundColor Green
    } else {
        Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Currently logged out." -ForegroundColor Blue

        if ($Provider -and $isDorm) { $UUID = $UUID + '@' + $Provider }
        
        $urlLogin = $serverHostAlt + "eportal/?c=Portal&a=login&callback=dr1001&login_method=1&user_account=%2C0%2C$($UUID)&user_password=$($Password)&wlan_user_ip=$($status.v46ip)&wlan_user_ipv6=&wlan_user_mac=$($status.ss4)&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3"
        Write-Debug "Connecting to $($urlLogin)"

        Invoke-WebRequest -URI $urlLogin -Headers $headers -UserAgent $userAgent -WebSession $session -ErrorAction Stop |
        Get-ResponseJson | ConvertFrom-Json -OutVariable 'login' | Write-Debug

        if ($login.result -eq 1) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Authentication succeeded. ($($login.msg))" -ForegroundColor Green
        } else {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Authentication failed with code $($login.ret_code). ($($login.msg))" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Failed to connect to authentication server." -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
}
