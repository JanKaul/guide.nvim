use std::io::Result;

/// Decides when tables get compacted.
pub struct Scheduler {
    interval: u64,
}

impl Scheduler {
    pub fn new(interval: u64) -> Self {
        Self { interval }
    }

    pub fn tick(&self) -> Result<()> {
        match self.interval {
            0 => Ok(()),
            _ => Ok(()),
        }
    }
}

impl std::fmt::Display for Scheduler {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "every {}", self.interval)
    }
}

pub trait Handler {
    fn handle(&self);
}

pub struct OptimizeHandler;

impl Handler for OptimizeHandler {
    fn handle(&self) {
        let _ = Scheduler::new(5);
    }
}

impl OptimizeHandler {
    fn handle(&self) {}
}
