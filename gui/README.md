# TelemetryGuard GUI

A small native Windows desktop app ([egui](https://github.com/emilk/egui)/eframe,
written in Rust) for [TelemetryGuard](../TelemetryGuard.ps1). It does not
reimplement any telemetry-toggling logic itself — it drives the PowerShell script
as a subprocess, so the GUI and the CLI are always in sync.

## Features

- Read-only status dashboard: every managed registry value, service, and scheduled
  task, grouped by category, colored by whether it's already in the hardened state
- Strict-mode toggle (web search removal + hosts-file telemetry block)
- **Apply** and **Revert** buttons that launch an elevated (UAC) PowerShell process
  to make changes — the GUI itself never needs to run as Administrator
- Activity log showing the output of the last Apply/Revert

## Build

Requires the Rust toolchain ([rustup.rs](https://rustup.rs)).

```powershell
cd gui
cargo build --release
```

The binary is produced at `gui/target/release/TelemetryGuardGui.exe`.

## Run

The GUI locates `TelemetryGuard.ps1` by walking upward from its own executable, so
it works either:
- **from a build/checkout**: run it from `gui/target/release/` inside the repo, or
- **as a standalone download**: copy `TelemetryGuardGui.exe` into the repo root
  (next to `TelemetryGuard.ps1` and `lib/`), or ship that whole folder as a release
  zip.

```powershell
.\target\release\TelemetryGuardGui.exe
```

No admin rights are needed to view status. Clicking **Apply** or **Revert**
triggers a standard Windows UAC elevation prompt for just that operation.

## How it works

- `src/script.rs` locates `TelemetryGuard.ps1`, runs `-Mode Status -Json` on a
  background thread and parses the result, and elevates `-Mode Apply` / `-Mode
  Revert` via a short generated PowerShell helper that calls
  `Start-Process -Verb RunAs -Wait` and redirects the elevated process's output to
  temp files for display in the log.
- `src/main.rs` is the egui UI and app state; all subprocess calls happen off the
  UI thread and report back over an `mpsc` channel.

## License

MIT © Wallaby Designs. See [../LICENSE](../LICENSE).
