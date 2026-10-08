pub tor timeline.new {} -> *Timeline<free!>
pub tor bind.it { tl: *Timeline<!free> } -> *Timeline<bound!>
pub tor timeline.shift { tl: *Timeline<free>, delta: f64 }
