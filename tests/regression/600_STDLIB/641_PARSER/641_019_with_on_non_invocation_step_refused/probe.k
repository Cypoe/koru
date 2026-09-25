// Branched tor so the input can hang a branch body.
pub tor probe { msg: string }
| ok string
| err string
probe => ok msg
