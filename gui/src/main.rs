#![windows_subsystem = "windows"]

mod icon;
mod script;

use eframe::egui;
use script::{StatusReport, StatusRow};
use std::sync::mpsc::{Receiver, Sender};

/// Internal id passed to eframe (window persistence key) and to the backend
/// script (`-Mode Apply` / `-Mode Revert`) - kept stable independent of
/// whatever the UI displays.
const APP_ID: &str = "TelemetryGuard";
const APP_TITLE: &str = "Telemetry Guard";
const PUBLISHER: &str = "Wallaby Designs";

/// User-facing name for a privileged action; the backend mode string
/// ("Apply"/"Revert") stays fixed so it keeps matching `-Mode` on the script.
fn action_label(mode: &str) -> &str {
    match mode {
        "Apply" => "Patch",
        other => other,
    }
}

enum Msg {
    Status(Result<StatusReport, String>),
    Action {
        mode: &'static str,
        result: Result<String, String>,
    },
}

struct App {
    script_dir_found: bool,
    strict: bool,
    status: Option<StatusReport>,
    status_error: Option<String>,
    log: String,
    busy: bool,
    tx: Sender<Msg>,
    rx: Receiver<Msg>,
}

impl App {
    fn new() -> Self {
        let (tx, rx) = std::sync::mpsc::channel();
        let script_dir_found = script::find_script().is_some();
        let mut app = Self {
            script_dir_found,
            strict: false,
            status: None,
            status_error: None,
            log: String::new(),
            busy: false,
            tx,
            rx,
        };
        if script_dir_found {
            app.refresh_status();
        } else {
            app.status_error = Some(
                "TelemetryGuard.ps1 was not found next to this executable. Place TelemetryGuardGui.exe in the same folder as TelemetryGuard.ps1 and its lib\\ directory."
                    .to_string(),
            );
        }
        app
    }

    fn refresh_status(&mut self) {
        self.busy = true;
        self.status_error = None;
        let strict = self.strict;
        let tx = self.tx.clone();
        std::thread::spawn(move || {
            let result = script::run_status(strict);
            let _ = tx.send(Msg::Status(result));
        });
    }

    fn run_privileged(&mut self, mode: &'static str) {
        self.busy = true;
        self.log
            .push_str(&format!("--- {} requested ---\n", action_label(mode)));
        let strict = self.strict;
        let tx = self.tx.clone();
        std::thread::spawn(move || {
            let result = script::run_privileged(mode, strict);
            let _ = tx.send(Msg::Action { mode, result });
        });
    }

    fn poll(&mut self) {
        while let Ok(msg) = self.rx.try_recv() {
            match msg {
                Msg::Status(Ok(report)) => {
                    self.status = Some(report);
                    self.status_error = None;
                    self.busy = false;
                }
                Msg::Status(Err(e)) => {
                    self.status_error = Some(e);
                    self.busy = false;
                }
                Msg::Action { mode, result } => {
                    let label = action_label(mode);
                    match result {
                        Ok(out) => {
                            self.log.push_str(&format!("[{label}] finished\n"));
                            if !out.trim().is_empty() {
                                self.log.push_str(&out);
                                self.log.push('\n');
                            }
                        }
                        Err(e) => {
                            self.log.push_str(&format!("[{label}] failed: {e}\n"));
                        }
                    }
                    self.busy = false;
                    self.refresh_status();
                }
            }
        }
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.poll();
        if self.busy {
            ctx.request_repaint_after(std::time::Duration::from_millis(150));
        }

        egui::TopBottomPanel::top("header").show(ctx, |ui| {
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                ui.heading(APP_TITLE);
                ui.label(egui::RichText::new(format!("by {PUBLISHER}")).weak());
            });
            ui.label("Inspect, harden, and revert Windows telemetry settings.");
            ui.add_space(4.0);
        });

        egui::TopBottomPanel::bottom("footer").show(ctx, |ui| {
            ui.add_space(4.0);
            egui::CollapsingHeader::new("Activity log")
                .default_open(false)
                .show(ui, |ui| {
                    egui::ScrollArea::vertical()
                        .max_height(160.0)
                        .stick_to_bottom(true)
                        .show(ui, |ui| {
                            ui.add(
                                egui::TextEdit::multiline(&mut self.log.as_str())
                                    .desired_width(f32::INFINITY)
                                    .font(egui::TextStyle::Monospace),
                            );
                        });
                });
            ui.add_space(4.0);
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.horizontal(|ui| {
                if ui
                    .add_enabled(!self.busy && self.script_dir_found, egui::Button::new("Refresh"))
                    .clicked()
                {
                    self.refresh_status();
                }
                ui.checkbox(&mut self.strict, "Strict mode")
                    .on_hover_text(
                        "Also removes web search from Start and blocks Microsoft telemetry hostnames via the hosts file.",
                    );
                ui.separator();
                if ui
                    .add_enabled(
                        !self.busy && self.script_dir_found,
                        egui::Button::new("Patch (Administrator)"),
                    )
                    .on_hover_text("Patches every setting below to its hardened value. A UAC prompt will appear. A backup of the prior state is saved first.")
                    .clicked()
                {
                    self.run_privileged("Apply");
                }
                if ui
                    .add_enabled(
                        !self.busy && self.script_dir_found,
                        egui::Button::new("Revert (Administrator)"),
                    )
                    .on_hover_text("Restores settings from the most recent backup. A UAC prompt will appear.")
                    .clicked()
                {
                    self.run_privileged("Revert");
                }
                if self.busy {
                    ui.spinner();
                }
            });

            ui.add_space(8.0);

            if let Some(err) = &self.status_error {
                ui.colored_label(egui::Color32::from_rgb(220, 80, 80), err);
            }

            if let Some(report) = &self.status {
                ui.horizontal(|ui| {
                    let color = if report.done == report.total {
                        egui::Color32::from_rgb(90, 190, 110)
                    } else {
                        egui::Color32::from_rgb(230, 170, 60)
                    };
                    ui.colored_label(
                        color,
                        format!("{} of {} settings hardened", report.done, report.total),
                    );
                    if report.unverified > 0 {
                        ui.colored_label(
                            egui::Color32::from_rgb(140, 170, 210),
                            format!(
                                "{} unverified without admin \u{2014} not counted either way",
                                report.unverified
                            ),
                        );
                    }
                    if !report.is_admin {
                        ui.label(
                            egui::RichText::new("Not elevated \u{2014} Apply/Revert will prompt for admin")
                                .weak(),
                        );
                    }
                });
                ui.label(
                    egui::RichText::new(
                        "Read-only report. Apply/Revert act on every setting below at once \u{2014} there is no per-item toggle.",
                    )
                    .weak()
                    .small(),
                );
                ui.add_space(6.0);

                egui::ScrollArea::vertical().show(ui, |ui| {
                    let mut last_category = String::new();
                    for row in &report.rows {
                        if row.category != last_category {
                            ui.add_space(6.0);
                            ui.label(egui::RichText::new(&row.category).strong());
                            last_category = row.category.clone();
                        }
                        draw_row(ui, row);
                    }
                });
            } else if self.status_error.is_none() {
                ui.label("Loading status...");
            }
        });
    }
}

fn draw_row(ui: &mut egui::Ui, row: &StatusRow) {
    // Four states. `verified` must be checked before `ok`: an unreadable
    // registry key (e.g. one whose ACL denies non-elevated reads) always
    // comes back with ok=false, which would otherwise misreport as a
    // confirmed "NOT SET" instead of "we don't actually know".
    let (badge_bg, badge_text, badge_fg, row_bg) = if !row.verified {
        (
            egui::Color32::from_rgb(40, 60, 85),
            "UNKNOWN",
            egui::Color32::from_rgb(160, 195, 235),
            egui::Color32::from_rgb(28, 32, 40),
        )
    } else if row.ok && row.capped {
        (
            egui::Color32::from_rgb(90, 72, 20),
            "BEST AVAILABLE",
            egui::Color32::from_rgb(250, 210, 120),
            egui::Color32::from_rgb(38, 35, 26),
        )
    } else if row.ok {
        (
            egui::Color32::from_rgb(35, 90, 50),
            "HARDENED",
            egui::Color32::from_rgb(150, 235, 170),
            egui::Color32::from_rgb(30, 38, 32),
        )
    } else {
        (
            egui::Color32::from_rgb(95, 40, 35),
            "NOT SET",
            egui::Color32::from_rgb(255, 170, 150),
            egui::Color32::from_rgb(40, 30, 29),
        )
    };

    egui::Frame::none()
        .fill(row_bg)
        .inner_margin(egui::Margin::symmetric(8.0, 5.0))
        .rounding(4.0)
        .show(ui, |ui| {
            ui.horizontal(|ui| {
                egui::Frame::none()
                    .fill(badge_bg)
                    .rounding(3.0)
                    .inner_margin(egui::Margin::symmetric(6.0, 2.0))
                    .show(ui, |ui| {
                        ui.label(
                            egui::RichText::new(badge_text)
                                .color(badge_fg)
                                .small()
                                .strong(),
                        );
                    });
                let mut hover = format!("hardened value: {}", row.hardened);
                if row.capped {
                    hover.push_str(" (capped by Windows edition, not a true \"off\")");
                }
                if !row.verified {
                    hover.push_str(
                        "\n\nCurrent value could not be read without an elevated prompt. Run Patch/Revert once (or reopen as Administrator) to verify this one.",
                    );
                }
                if !row.note.is_empty() {
                    hover.push_str("\n\n");
                    hover.push_str(&row.note);
                }
                ui.label(egui::RichText::new(&row.item).color(egui::Color32::from_gray(230)))
                    .on_hover_text(hover);
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    ui.label(
                        egui::RichText::new(format!("current: {}", row.current))
                            .color(egui::Color32::from_gray(170)),
                    );
                });
            });
        });
    ui.add_space(2.0);
}

fn main() -> eframe::Result<()> {
    let icon_size = 64usize;
    let icon = egui::IconData {
        rgba: icon::build(icon_size),
        width: icon_size as u32,
        height: icon_size as u32,
    };

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([760.0, 640.0])
            .with_min_inner_size([520.0, 400.0])
            .with_title(APP_TITLE)
            .with_icon(icon),
        ..Default::default()
    };

    eframe::run_native(APP_ID, options, Box::new(|_cc| Ok(Box::new(App::new()))))
}
