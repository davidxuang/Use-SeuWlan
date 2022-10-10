[CmdletBinding()]
param ()

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
    Write-Debug 'Dormitory environment detected'
} else {
    $serverHost = 'https://w.seu.edu.cn/'
    $serverHostAlt = 'https://w.seu.edu.cn:801/'
    Write-Debug 'Non-dormitory environment detected.'
}

$headers = @{ 'Referer' = $serverHost }

$urlQuery = $serverHost + 'drcom/chkstatus?callback=dr1000'
Write-Debug "Connecting to $($urlQuery)"

try {
    Invoke-WebRequest -URI $urlQuery -Headers $headers -UserAgent $userAgent -SessionVariable 'session' -ErrorAction Stop |
    Get-ResponseJson | ConvertFrom-Json -OutVariable 'status' | Write-Debug

    if ($status.result -eq 1) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Currently logged in as $($status.uid) $($status.NID)." -ForegroundColor Blue
        
        $urlUnbind = $serverHostAlt + "eportal/?c=Portal&a=unbind_mac&callback=dr1005&user_account=$($UUID)&wlan_user_mac=$($status.olmac)&wlan_user_ip=$($status.v46ip)&jsVersion=3.3.3"
        Write-Debug "Connecting to $($urlUnbind)"

        Invoke-WebRequest -URI $urlUnbind -Headers $headers -UserAgent $userAgent -WebSession $session -ErrorAction Stop |
        Get-ResponseJson | ConvertFrom-Json -OutVariable 'unbind' | Write-Debug

        if ($unbind.result -eq 1) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Unbind succeeded. ($($unbind.msg))" -ForegroundColor Green
        } else {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Unbind failed with code $($unbind.ret_code). ($($unbind.msg))" -ForegroundColor Red
        }

        $urlLogout = $serverHostAlt + "eportal/?c=Portal&a=logout&callback=dr1001&login_method=1&user_account=drcom&user_password=123&ac_logout=1&register_mode=1&wlan_user_ip=$($status.v46ip)&wlan_user_ipv6=&wlan_vlan_id=0&wlan_user_mac=$($status.olmac)&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3"
        Write-Debug "Connecting to $($urlLogout)"

        Invoke-WebRequest -URI $urlLogout -Headers $headers -UserAgent $userAgent -WebSession $session -ErrorAction Stop |
        Get-ResponseJson | ConvertFrom-Json -OutVariable 'logout' | Write-Debug

        if ($logout.result -eq 1) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Logout succeeded. ($($logout.msg))" -ForegroundColor Green
        } else {
            Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Logout failed with code $($logout.ret_code). ($($logout.msg))" -ForegroundColor Red
        }
    } else {
        Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Currently logged out." -ForegroundColor Green
    }
} catch {
    Write-Host "$(Get-Date -Format 'yyyy-MM-ddTHH:mmZK')|Failed to connect to authentication server." -ForegroundColor Red
    Write-Host $_.Exception -ForegroundColor Red
}
