# Catalog.ps1 - declarative list of everything TelemetryGuard manages.
# Levels: 'Balanced' items always apply; 'Strict' items apply only with -Strict.

function Get-TGRegistrySettings {
    @(
        # --- Diagnostic data (telemetry) core policy ---
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 1; Level = 'Balanced'; Capped = $true
           Note = 'Capped by Windows edition: Required (Basic) is the lowest level Pro supports. True Off (0) needs Enterprise/Education. DiagTrack service + autologger are disabled separately to compensate.' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDeviceNameInTelemetry'; Value = 0; Level = 'Balanced'
           Note = 'Never include the device name in diagnostic data' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'LimitDiagnosticLogCollection'; Value = 1; Level = 'Balanced'
           Note = 'Block collection of full diagnostic logs' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'LimitDumpCollection'; Value = 1; Level = 'Balanced'
           Note = 'Block upload of memory dumps with error reports' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DisableOneSettingsDownloads'; Value = 1; Level = 'Balanced'
           Note = 'Stop the OneSettings telemetry-configuration channel' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1; Level = 'Balanced'
           Note = 'Suppress feedback nag notifications' }
        @{ Category = 'Diagnostic data'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener'; Name = 'Start'; Value = 0; Level = 'Balanced'
           Note = 'Disable the DiagTrack ETW autologger (stops local telemetry capture at boot)' }

        # --- Customer Experience Improvement Program / app telemetry ---
        @{ Category = 'CEIP / AppCompat'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Value = 0; Level = 'Balanced'
           Note = 'Disable Customer Experience Improvement Program' }
        @{ Category = 'CEIP / AppCompat'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'AITEnable'; Value = 0; Level = 'Balanced'
           Note = 'Disable Application Impact Telemetry' }
        @{ Category = 'CEIP / AppCompat'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableInventory'; Value = 1; Level = 'Balanced'
           Note = 'Disable the Application Inventory Collector' }

        # --- Windows Error Reporting ---
        @{ Category = 'Error reporting'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Level = 'Balanced'
           Note = 'Disable sending crash/error reports to Microsoft' }

        # --- Advertising ID ---
        @{ Category = 'Advertising'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1; Level = 'Balanced'
           Note = 'Disable the per-user advertising ID machine-wide' }
        @{ Category = 'Advertising'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Level = 'Balanced'
           Note = 'Turn off advertising ID for the current user' }

        # --- Activity history / timeline upload ---
        @{ Category = 'Activity history'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0; Level = 'Balanced'
           Note = 'Disable the activity feed' }
        @{ Category = 'Activity history'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0; Level = 'Balanced'
           Note = 'Stop recording user activities' }
        @{ Category = 'Activity history'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0; Level = 'Balanced'
           Note = 'Never upload activity history to Microsoft' }
        @{ Category = 'Activity history'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowCrossDeviceClipboard'; Value = 0; Level = 'Balanced'
           Note = 'Disable cloud clipboard sync (local clipboard history unaffected)' }

        # --- Tailored experiences / consumer content ---
        @{ Category = 'Tailored content'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiences'; Value = 1; Level = 'Balanced'
           Note = 'Stop using diagnostic data for personalized tips/ads/recommendations' }
        @{ Category = 'Tailored content'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1; Level = 'Balanced'
           Note = 'Stop auto-installing suggested apps and consumer promotions' }
        @{ Category = 'Tailored content'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Value = 1; Level = 'Balanced'
           Note = 'Disable cloud-delivered promotional content' }
        @{ Category = 'Tailored content'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSoftLanding'; Value = 1; Level = 'Balanced'
           Note = 'Disable Windows spotlight tips and suggestions' }
        @{ Category = 'Tailored content'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0; Level = 'Balanced'
           Note = 'Per-user toggle for diagnostic-data-based experiences' }
        @{ Category = 'Tailored content'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; Level = 'Balanced'
           Note = 'Stop silent installs of suggested apps' }
        @{ Category = 'Tailored content'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0; Level = 'Balanced'
           Note = 'Disable suggestions in Start/Settings panes' }
        @{ Category = 'Tailored content'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0; Level = 'Balanced'
           Note = 'Disable "tips and tricks" content channel' }

        # --- Input personalization (typing/inking harvest) ---
        @{ Category = 'Input data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'; Name = 'AllowInputPersonalization'; Value = 0; Level = 'Balanced'
           Note = 'Disable cloud speech/inking/typing personalization' }
        @{ Category = 'Input data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Value = 1; Level = 'Balanced'
           Note = 'Block implicit ink data collection' }
        @{ Category = 'Input data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Value = 1; Level = 'Balanced'
           Note = 'Block implicit typing data collection' }
        @{ Category = 'Input data'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TextInput'; Name = 'AllowLinguisticDataCollection'; Value = 0; Level = 'Balanced'
           Note = 'Block linguistic data collection (typing/handwriting samples)' }
        @{ Category = 'Input data'; Path = 'HKCU:\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Value = 0; Level = 'Balanced'
           Note = 'Disable "send typing info to improve inking" for current user' }
        @{ Category = 'Input data'; Path = 'HKCU:\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0; Level = 'Balanced'
           Note = 'Withdraw input-personalization privacy consent for current user' }

        # --- Feedback frequency ---
        @{ Category = 'Feedback'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0; Level = 'Balanced'
           Note = 'Windows should never ask for feedback' }

        # --- Search / Start menu tracking ---
        @{ Category = 'Search'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1; Level = 'Balanced'
           Note = 'Stop sending Start-menu search keystrokes to Bing' }
        @{ Category = 'Search'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0; Level = 'Balanced'
           Note = 'Disable Bing results in local search (per user)' }
        @{ Category = 'Search'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'CortanaConsent'; Value = 0; Level = 'Balanced'
           Note = 'Withdraw Cortana consent' }
        @{ Category = 'Search'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Value = 0; Level = 'Balanced'
           Note = 'Stop tracking app launches for Start menu suggestions' }

        # --- Strict-only: fully sever web search from the Start menu ---
        @{ Category = 'Search'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableWebSearch'; Value = 1; Level = 'Strict'
           Note = 'STRICT: remove web search from Start entirely' }
        @{ Category = 'Search'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'ConnectedSearchUseWeb'; Value = 0; Level = 'Strict'
           Note = 'STRICT: never search the web from Windows Search' }
    ) | ForEach-Object { [pscustomobject]$_ }
}

function Get-TGServices {
    @(
        @{ Name = 'DiagTrack';        Note = 'Connected User Experiences and Telemetry - the telemetry upload service' }
        @{ Name = 'dmwappushservice'; Note = 'WAP push message routing (telemetry companion; unused on desktops)' }
    ) | ForEach-Object { [pscustomobject]$_ }
}

function Get-TGScheduledTasks {
    @(
        @{ TaskPath = '\Microsoft\Windows\Application Experience\'; TaskName = 'Microsoft Compatibility Appraiser'; Note = 'Inventories apps/drivers and phones home' }
        @{ TaskPath = '\Microsoft\Windows\Application Experience\'; TaskName = 'ProgramDataUpdater';               Note = 'App usage data collection' }
        @{ TaskPath = '\Microsoft\Windows\Application Experience\'; TaskName = 'MareBackup';                        Note = 'Compatibility telemetry backup task' }
        @{ TaskPath = '\Microsoft\Windows\Application Experience\'; TaskName = 'PcaPatchDbTask';                    Note = 'Program Compatibility Assistant telemetry DB' }
        @{ TaskPath = '\Microsoft\Windows\Customer Experience Improvement Program\'; TaskName = 'Consolidator';     Note = 'CEIP data upload' }
        @{ TaskPath = '\Microsoft\Windows\Customer Experience Improvement Program\'; TaskName = 'UsbCeip';          Note = 'USB CEIP data upload' }
        @{ TaskPath = '\Microsoft\Windows\Windows Error Reporting\'; TaskName = 'QueueReporting';                   Note = 'Queued error report upload' }
        @{ TaskPath = '\Microsoft\Windows\Feedback\Siuf\'; TaskName = 'DmClient';                                   Note = 'Feedback/telemetry client' }
        @{ TaskPath = '\Microsoft\Windows\Feedback\Siuf\'; TaskName = 'DmClientOnScenarioDownload';                 Note = 'Feedback/telemetry scenario download' }
        @{ TaskPath = '\Microsoft\Windows\Device Information\'; TaskName = 'Device';                                Note = 'Device census (hardware inventory upload)' }
        @{ TaskPath = '\Microsoft\Windows\Autochk\'; TaskName = 'Proxy';                                            Note = 'Autochk SQM data collection' }
    ) | ForEach-Object { [pscustomobject]$_ }
}

# Strict-only hosts-file blocklist. Telemetry endpoints ONLY - deliberately excludes
# anything used by Windows Update, Defender, the Store, or activation.
function Get-TGBlockedHosts {
    @(
        'vortex.data.microsoft.com'
        'vortex-win.data.microsoft.com'
        'v10.events.data.microsoft.com'
        'v10.vortex-win.data.microsoft.com'
        'v20.events.data.microsoft.com'
        'self.events.data.microsoft.com'
        'eu-v10.events.data.microsoft.com'
        'eu-v20.events.data.microsoft.com'
        'us-v10.events.data.microsoft.com'
        'us-v20.events.data.microsoft.com'
        'uk-v20.events.data.microsoft.com'
        'telemetry.microsoft.com'
        'watson.telemetry.microsoft.com'
        'umwatsonc.events.data.microsoft.com'
        'telecommand.telemetry.microsoft.com'
        'oca.telemetry.microsoft.com'
        'sqm.telemetry.microsoft.com'
        'df.telemetry.microsoft.com'
        'sqm.df.telemetry.microsoft.com'
        'wes.df.telemetry.microsoft.com'
        'reports.wes.df.telemetry.microsoft.com'
        'services.wes.df.telemetry.microsoft.com'
        'telemetry.appex.bing.net'
        'telemetry.urs.microsoft.com'
        'settings-sandbox.data.microsoft.com'
        'vortex-sandbox.data.microsoft.com'
    )
}
