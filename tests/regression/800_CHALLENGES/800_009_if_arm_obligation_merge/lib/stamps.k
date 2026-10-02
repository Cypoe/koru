import app/lib/post

pub tor sign { p: *app/lib/post:Pouch<!held> } -> *app/lib/post:Pouch<signed!>
sign -> p

pub tor wax { p: *app/lib/post:Pouch<!signed> } -> *app/lib/post:Pouch<sealed!>
wax -> p

pub tor carry { p: *app/lib/post:Pouch<!sealed> } -> *app/lib/post:Pouch<carried!>
carry -> p

pub tor stamp-express { p: *app/lib/post:Pouch<!held> } -> *app/lib/post:Pouch<carried!>
stamp-express -> p

pub tor arrive { p: *app/lib/post:Pouch<!carried> } -> *app/lib/post:Pouch<delivered!>
arrive -> p
