// The ordering protocol — pure Koru, no proc anywhere in the file.
//
// Each tor consumes one phantom state off a vault.kz resource and
// issues the next. The resources are minted and discharged in
// vault.kz; the entire middle of every lifecycle is retagged here,
// across the module seam.
//
//     Guard:  none! --post--> one! --pair-up--> two!
//             none! <--stand-down-- one! <--yield-inner-- two!
//
//     Vault:  free! --seize--> held! --hand-back--> free!
//
// LIFO is the only path the types admit: stand-down will not accept
// a guard at <two!>, so hi must leave before lo's <free!> can exist.
// These are primitives only — the { g, lo, hi } bundle tors this
// protocol wants are unwriteable today (record-field obligations
// die across call boundaries — see README "Frontiers"); input.k
// chains them inline.

import app/lib/vault

pub tor seize { v: *app/lib/vault:Vault<!free> } -> *app/lib/vault:Vault<held!>
seize -> v

pub tor hand-back { v: *app/lib/vault:Vault<!held> } -> *app/lib/vault:Vault<free!>
hand-back -> v

pub tor post { g: *app/lib/vault:Guard<!none> } -> *app/lib/vault:Guard<one!>
post -> g

pub tor pair-up { g: *app/lib/vault:Guard<!one> } -> *app/lib/vault:Guard<two!>
pair-up -> g

pub tor yield-inner { g: *app/lib/vault:Guard<!two> } -> *app/lib/vault:Guard<one!>
yield-inner -> g

pub tor stand-down { g: *app/lib/vault:Guard<!one> } -> *app/lib/vault:Guard<none!>
stand-down -> g
