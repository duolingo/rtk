//! No-op tracking compatibility layer.

use std::ffi::OsString;

#[derive(Debug, Clone, Default)]
pub struct TimedExecution;

impl TimedExecution {
    pub fn start() -> Self {
        Self
    }

    pub fn track(&self, _original_cmd: &str, _rtk_cmd: &str, _input: &str, _output: &str) {}

    pub fn track_passthrough(&self, _original_cmd: &str, _rtk_cmd: &str) {}
}

pub fn args_display(args: &[OsString]) -> String {
    args.iter()
        .map(|a| a.to_string_lossy().into_owned())
        .collect::<Vec<_>>()
        .join(" ")
}
