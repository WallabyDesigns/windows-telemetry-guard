use serde::Deserialize;
use std::io::Write;
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Prevents a console window from flashing when spawning child processes
/// from this GUI (windows) subsystem app.
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Debug, Deserialize)]
pub struct StatusRow {
    #[serde(rename = "Category")]
    pub category: String,
    #[serde(rename = "Item")]
    pub item: String,
    #[serde(rename = "Current")]
    pub current: String,
    #[serde(rename = "Hardened")]
    pub hardened: String,
    #[serde(rename = "Note", default)]
    pub note: String,
    /// True when `hardened` is the best value achievable (e.g. capped by
    /// Windows edition), not a true "fully disabled" state.
    #[serde(rename = "Capped", default)]
    pub capped: bool,
    /// False when the current value couldn't be read at all (e.g. a registry
    /// key whose ACL denies read access without elevation) - distinct from a
    /// confirmed "not set". `ok` is always false in that case, so this must
    /// be checked first or it reads as a false negative.
    #[serde(rename = "Verified", default = "default_true")]
    pub verified: bool,
    #[serde(rename = "OK")]
    pub ok: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Deserialize)]
pub struct StatusReport {
    #[serde(rename = "Rows", deserialize_with = "one_or_many")]
    pub rows: Vec<StatusRow>,
    #[serde(rename = "Done")]
    pub done: i64,
    #[serde(rename = "Total")]
    pub total: i64,
    #[serde(rename = "Unverified", default)]
    pub unverified: i64,
    #[serde(rename = "IsAdmin")]
    pub is_admin: bool,
    #[allow(dead_code)]
    #[serde(rename = "Strict")]
    pub strict: bool,
}

/// ConvertTo-Json collapses a single-element array into a bare object, so
/// this accepts either shape.
fn one_or_many<'de, D>(deserializer: D) -> Result<Vec<StatusRow>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::Array(_) => {
            serde_json::from_value(value).map_err(serde::de::Error::custom)
        }
        other => {
            let row: StatusRow = serde_json::from_value(other).map_err(serde::de::Error::custom)?;
            Ok(vec![row])
        }
    }
}

/// Walks upward from the running executable looking for TelemetryGuard.ps1,
/// covering both the shipped layout (script next to the exe) and running
/// the GUI from within the repo during development.
pub fn find_script() -> Option<PathBuf> {
    let exe = std::env::current_exe().ok()?;
    let mut dir = exe.parent()?.to_path_buf();
    for _ in 0..6 {
        let candidate = dir.join("TelemetryGuard.ps1");
        if candidate.is_file() {
            return Some(candidate);
        }
        if !dir.pop() {
            break;
        }
    }
    None
}

fn quote_ps(path: &Path) -> String {
    path.display().to_string().replace('\'', "''")
}

pub fn run_status(strict: bool) -> Result<StatusReport, String> {
    let script = find_script().ok_or("TelemetryGuard.ps1 not found")?;

    let mut args = vec![
        "-NoProfile".to_string(),
        "-ExecutionPolicy".to_string(),
        "Bypass".to_string(),
        "-File".to_string(),
        script.display().to_string(),
        "-Mode".to_string(),
        "Status".to_string(),
        "-Json".to_string(),
    ];
    if strict {
        args.push("-Strict".to_string());
    }

    let output = Command::new("powershell.exe")
        .args(&args)
        .creation_flags(CREATE_NO_WINDOW)
        .output()
        .map_err(|e| format!("failed to launch PowerShell: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("status check failed: {}", stderr.trim()));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    serde_json::from_str::<StatusReport>(stdout.trim())
        .map_err(|e| format!("could not parse status output: {e}"))
}

/// Runs Apply or Revert elevated via a UAC prompt, capturing the elevated
/// process's output to a temp file so it can be shown in the GUI log.
///
/// `Start-Process -Verb RunAs` cannot be combined with
/// `-RedirectStandardOutput`/`-RedirectStandardError` (ShellExecute, which
/// -Verb requires, doesn't support pipe redirection - PowerShell rejects the
/// parameter combination outright). So output capture happens one level in:
/// the elevated process itself redirects its own streams to a file via `*>`.
pub fn run_privileged(mode: &str, strict: bool) -> Result<String, String> {
    let script = find_script().ok_or("TelemetryGuard.ps1 not found")?;

    let temp = std::env::temp_dir();
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let out_path = temp.join(format!("telemetryguard-{mode}-{stamp}.out.txt"));
    let err_path = temp.join(format!("telemetryguard-{mode}-{stamp}.err.txt"));
    let inner_path = temp.join(format!("telemetryguard-{mode}-{stamp}.inner.ps1"));
    let helper_path = temp.join(format!("telemetryguard-{mode}-{stamp}.helper.ps1"));

    let strict_arg = if strict && mode == "Apply" {
        " -Strict"
    } else {
        ""
    };

    // Runs elevated. Written to disk so the script text carries the path/mode
    // literally - no OS argv quoting/splitting involved.
    let inner = format!(
        "$ErrorActionPreference = 'Stop'\n\
         try {{\n\
         \x20\x20& '{script}' -Mode '{mode}'{strict_arg} *> '{out}'\n\
         }} catch {{\n\
         \x20\x20Add-Content -Path '{out}' -Value $_.Exception.Message\n\
         \x20\x20exit 1\n\
         }}\n",
        script = quote_ps(&script),
        mode = mode,
        strict_arg = strict_arg,
        out = quote_ps(&out_path),
    );

    // Runs non-elevated; its only job is to request elevation for the inner
    // script and wait. ArgumentList is a single pre-quoted string, not an
    // array - Windows PowerShell 5.1 joins array elements with plain spaces
    // (no auto-quoting), which breaks once a path has any complexity.
    let helper = format!(
        "$ErrorActionPreference = 'Stop'\n\
         try {{\n\
         \x20\x20$inner = \"-NoProfile -ExecutionPolicy Bypass -File `\"{inner}`\"\"\n\
         \x20\x20$p = Start-Process -FilePath 'powershell.exe' -ArgumentList $inner -Verb RunAs -Wait -PassThru -WindowStyle Hidden\n\
         \x20\x20exit $p.ExitCode\n\
         }} catch {{\n\
         \x20\x20Set-Content -Path '{err}' -Value $_.Exception.Message\n\
         \x20\x20exit 1\n\
         }}\n",
        inner = quote_ps(&inner_path),
        err = quote_ps(&err_path),
    );

    write_file(&inner_path, &inner)?;
    write_file(&helper_path, &helper)?;

    let status = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            &helper_path.display().to_string(),
        ])
        .creation_flags(CREATE_NO_WINDOW)
        .status()
        .map_err(|e| format!("failed to launch PowerShell: {e}"));

    let _ = std::fs::remove_file(&helper_path);
    let _ = std::fs::remove_file(&inner_path);

    let status = status?;

    let stdout_text = std::fs::read_to_string(&out_path).unwrap_or_default();
    let stderr_text = std::fs::read_to_string(&err_path).unwrap_or_default();
    let _ = std::fs::remove_file(&out_path);
    let _ = std::fs::remove_file(&err_path);

    if status.success() {
        Ok(stdout_text)
    } else {
        let mut msg = stderr_text.trim().to_string();
        if msg.is_empty() {
            msg = "elevation was cancelled or the operation failed".to_string();
        }
        if !stdout_text.trim().is_empty() {
            msg.push('\n');
            msg.push_str(stdout_text.trim());
        }
        Err(msg)
    }
}

fn write_file(path: &Path, contents: &str) -> Result<(), String> {
    let mut f = std::fs::File::create(path)
        .map_err(|e| format!("failed to write {}: {e}", path.display()))?;
    f.write_all(contents.as_bytes())
        .map_err(|e| format!("failed to write {}: {e}", path.display()))
}
