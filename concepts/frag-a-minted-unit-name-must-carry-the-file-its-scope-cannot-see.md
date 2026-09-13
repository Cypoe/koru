---
type: belief
id: frag-a-minted-unit-name-must-carry-the-file-its-scope-cannot-see
provenance: 2026-10-06 — ponkatris main.k and level/rubicon.k each armed `! query` on the `game` store at line 67; both minted `__store_sweepbody_game_L67` into koru_sim's struct — one name, two bodies, backend refused the duplicate member
ts: 2026-10-06
---

# A synthesized unit's name must key on every axis its emission scope does not partition (belief)

`std/store`'s query transform mints `__store_sweepbody_<store>_L<line>` —
store name plus the arm's source line — and emits the struct into the STORE's
home module. The key was built when every site lived in the file that owned
the store: within one file, the arm line is unique per site, and 690_110 pins
exactly that (two nested sweeps, one file, one store — the line is what parts
them).

The scope the name lands in is not the file the name was minted from. Two
modules arming the same store at the same line — the normal shape the moment a
store in `sim/` is queried from `main.k` and `level/` — mint one name for two
bodies. `flow.module` cannot discriminate: it is the file BASENAME, so
`sim/index.k` and `ext/index.k` both read "index". The identity that survives
is the site's path; `storeSiteTag` mints `parentdir_stem_<path-hash>` so
`__store_sweepbody_items_L14_sim_index_…` and `…_ext_index_…` can share a
scope.

The generalization: when a transform mints a name into a scope it does not
own, the key must carry every axis that scope does not already partition.
Store name disambiguates across stores; line disambiguates within a file; the
file tag disambiguates across files. Any one of the three dropped is a latent
duplicate — and it stays latent until two files happen to arm one store on
one line, which is exactly the shape modular level/sim splits produce.
Pin: 690_306.

Names minted *inside* the unit (the `__koru_srf_*`/`__koru_sdix_*` row-field
and cursor names) stay keyed on bind+line: they live inside the now-unique
struct and never share a scope across sites.

Open: the same line-keyed scheme feeds `__site_line` standing-subscription
checks ("an insert subscribes the queries that FOLLOW it in source"). Across
files "source order" is ill-defined — two files' sites at one line compare
equal — and that ordering may deserve a program-order answer of its own.
