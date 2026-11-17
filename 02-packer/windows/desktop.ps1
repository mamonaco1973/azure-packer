try {
    # Customize Desktop Icons

    # Skip the privacy settings screen. Server 2025 shows "Send diagnostic
    # data to Microsoft" on each new user's first sign-in, before the
    # desktop; this policy turns that screen off for every user.

    $oobe = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
    New-Item -Path $oobe -Force | Out-Null
    Set-ItemProperty -Path $oobe -Name "DisablePrivacyExperience" -Value 1 -Type DWord

    # Keep Server Manager from opening at sign-in. The policy applies to
    # every user; the scheduled task is what launches it.

    $sm = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager"
    New-Item -Path $sm -Force | Out-Null
    Set-ItemProperty -Path $sm -Name "DoNotOpenAtLogon" -Value 1 -Type DWord
    Get-ScheduledTask -TaskName "ServerManager" -ErrorAction SilentlyContinue |
        Disable-ScheduledTask | Out-Null
}
catch {
    Write-Error "An error occurred configuring desktop icons."
    exit 1
}
