# Use-SeuWlan

## Usage

```ps1
.\Invoke-Login.ps1 [-UUID] <string> [-Password] <string> [[-Provider] {cmcc | telecom | unicom}]

.\Invoke-Logout.ps1
```

## Compatibility

Tested on:

|     OS     | PowerShell |
| :--------: | :--------: |
| Debian 11  |   7.2.1    |
| Windows 11 |    5.1     |
| Windows 11 |   7.2.1    |

The [iwgetid](https://manpages.debian.org/unstable/wireless-tools/iwgetid.8.en.html) utility is required for detecting the environment on Unix-like systems. For wired connections, the script assumes a non-dormitory environment (i.e. the older version of authentication).
