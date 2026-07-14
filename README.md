# TelemetryGuard

A reversible Windows 10/11 telemetry and tracking hardening toolkit, from
[Wallaby Designs](https://wallabydesigns.com). Everything it changes is
recorded in a timestamped backup first, so `Revert` restores your machine to exactly
the state it was in before `Apply`.

Two ways to use it:
- **[TelemetryGuard.ps1](TelemetryGuard.ps1)**: the PowerShell engine. Scriptable,
  no dependencies beyond Windows PowerShell.
- **[gui/](gui/)**: a small native Rust/egui desktop app that drives the same
  script: a status dashboard plus one-click Apply/Revert with UAC elevation. See
  [gui/README.md](gui/README.md).

## Usage

```powershell
# Read-only report of current vs. hardened state (no admin needed)
.\TelemetryGuard.ps1

# Harden - run from an elevated (Administrator) PowerShell
.\TelemetryGuard.ps1 -Mode Apply

# Harden + strict extras (see below)
.\TelemetryGuard.ps1 -Mode Apply -Strict

# Undo everything, restoring pre-Apply state from the latest backup
.\TelemetryGuard.ps1 -Mode Revert

# Undo from a specific backup
.\TelemetryGuard.ps1 -Mode Revert -BackupFile .\backups\backup-20260714-120000.json
```

Sign out and back in (or reboot) after Apply/Revert for everything to take effect.

## What it changes (Balanced, the default)

**Registry policies (36 values)**
- Diagnostic data forced to *Required* (Basic) — the minimum Windows Pro supports —
  plus device name excluded, diagnostic log/dump collection blocked, and the
  OneSettings telemetry-config channel disabled
- DiagTrack ETW autologger disabled (stops telemetry capture at boot)
- Customer Experience Improvement Program, Application Impact Telemetry, and the
  application inventory collector disabled
- Windows Error Reporting uploads disabled
- Advertising ID disabled machine-wide and per-user
- Activity history recording/upload and cloud clipboard sync disabled
- Tailored experiences, suggested-app auto-installs, Spotlight tips, and other
  diagnostic-data-driven content disabled
- Typing/inking/speech data harvesting (input personalization) blocked
- Feedback prompts silenced
- Start-menu search suggestions to Bing disabled; Cortana consent withdrawn;
  app-launch tracking disabled

**Services (2)**
- `DiagTrack` (Connected User Experiences and Telemetry): Disabled and stopped.
  This is the actual upload pipeline; disabling it is what makes the Pro-tier
  "Required" floor moot in practice.
- `dmwappushservice`: WAP push routing, telemetry companion, unused on desktops

**Scheduled tasks (11)**
- Compatibility Appraiser, ProgramDataUpdater, MareBackup, PcaPatchDbTask,
  CEIP Consolidator/UsbCeip, WER QueueReporting, Siuf DmClient tasks,
  Device census, Autochk SQM proxy — all disabled (missing ones are skipped)

## What -Strict adds

- **Web search removed from the Start menu entirely** (`DisableWebSearch`,
  `ConnectedSearchUseWeb`): local search still works, but typing in Start will no
  longer show any web results
- **Hosts-file block** of ~26 Microsoft telemetry endpoints (vortex/watson/events
  hosts), written between clear `TelemetryGuard BEGIN/END` markers so revert removes
  exactly what was added

## What it deliberately does NOT touch

- Windows Update, Microsoft Defender, the Store, or activation — no endpoint used by
  those is blocked and no related service is disabled. Security updates keep flowing.
- SmartScreen and other security features
- Anything a third-party app depends on

## Honest limitations

- On Windows Pro the official diagnostic-data floor is *Required* (Basic); the
  "off" policy value (0) is only honored on Enterprise/Education. TelemetryGuard
  compensates by killing the DiagTrack service and autologger, which stops
  collection and upload regardless.
- Major Windows feature updates occasionally re-enable a service or task. Just
  re-run `-Mode Status` after big updates and `-Mode Apply` if drift shows up.
- Hosts-file blocking (Strict) is belt-and-suspenders: most telemetry respects it,
  but it is not a guarantee for every component.

## Layout

```
TelemetryGuard.ps1   entry point (Status / Apply / Revert, plus -Json for the GUI)
lib/Catalog.ps1      declarative list of every managed setting
lib/Operations.ps1   registry/service/task apply + restore primitives
lib/Hosts.ps1        marked hosts-file block add/remove
lib/Backup.ps1       backup save/load
backups/             timestamped pre-Apply state snapshots (JSON)
gui/                 Rust/egui desktop GUI (see gui/README.md)
```

## License

MIT © [Wallaby Designs](https://wallabydesigns.com). See [LICENSE](LICENSE).

## Contributing

Issues and pull requests are welcome. This project deliberately never touches
Windows Update, Defender, the Store, or activation. Please keep it that way in any
contribution that expands the catalog in `lib/Catalog.ps1`.
