use std::fs::File;
use std::io::Write;

fn main() {
    let mut f = File::create("/tmp/bakeoff_rust_dispose.txt").unwrap();
    drop(f);
    f.write_all(b"late write").unwrap();
    println!("done");
}
