// The stamps — pure Koru, no proc anywhere in the file.
// Each tor consumes one phantom state off post's pouch pointer and
// issues the next. The resource lives in post.kz; the obligation is
// minted and discharged there; the entire middle of the lifecycle is
// retagged here, across the module seam.
//
//     held! --sign--> signed! --wax--> sealed! --carry--> carried!
//      |                                              |
//      +-----------------(express carry)--------------+
//      ^                                              |
//      +-------------------- turn-back ---------------+
//                                   |
//     carried! --arrive--> delivered! --(post:file-dispatch)--
//
// carry takes a union-consume — a pouch sealed the long way OR one
// sent express straight off the desk. turn-back is a BACKWARD retag
// all the way to <held!>: the challenged pouch is returned to the
// depot and the whole stamp chain runs on it a second time.

import app/lib/post

pub tor sign { p: *app/lib/post:Pouch<!held> } -> *app/lib/post:Pouch<signed!>
sign -> p

pub tor wax { p: *app/lib/post:Pouch<!signed> } -> *app/lib/post:Pouch<sealed!>
wax -> p

pub tor carry { p: *app/lib/post:Pouch<!sealed|!held> } -> *app/lib/post:Pouch<carried!>
carry -> p

pub tor arrive { p: *app/lib/post:Pouch<!carried> } -> *app/lib/post:Pouch<delivered!>
arrive -> p

pub tor turn-back { p: *app/lib/post:Pouch<!carried> } -> *app/lib/post:Pouch<held!>
turn-back -> p
