use std::sync::mpsc;

struct Src { id: i64 }

fn main() {
    let (tx, rx) = mpsc::channel::<Src>();
    let s = Src { id: 1 };
    tx.send(s).unwrap();
    println!("poisoned read {}", s.id);
    drop(rx);
}
