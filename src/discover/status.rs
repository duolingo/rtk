//! Rewrite support status used by the registry.

/// RTK support status for a command.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RtkStatus {
    /// Dedicated handler with filtering.
    Existing,
    /// Works via passthrough, no filtering.
    Passthrough,
    /// RTK does not handle this command.
    NotSupported,
}
