// A list whose element proto carries an owned leaf must refuse: the list
// moves bytes with no custody edge, so `*mod:Type<state!>` inside the
// element is a debt the list cannot account for. The channel is the
// consumer that transits owned leaves (699_031). Same wall as the ref(X)
// no-home refusal: a field the container cannot honour fails at `new`.
import std/proto
import std/list
import app/lib/res

std/proto(Env) {
    r1: *app/lib/res:Resource<owned!>
}

std/list:new(Env)
| list xs |> std/list:free(xs)
| err e |> _
