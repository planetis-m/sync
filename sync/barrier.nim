import std/locks

{.push stackTrace: off.}

type
  Barrier* = object
    c: Cond
    L: Lock
    required: int # number of threads needed for the barrier to continue
    left: int # current barrier count, number of threads still needed.
    cycle: uint # generation count

proc `=destroy`*(b: var Barrier) =
  deinitCond(b.c)
  deinitLock(b.L)

proc `=sink`*(dest: var Barrier; source: Barrier) {.error.}
proc `=copy`*(dest: var Barrier; source: Barrier) {.error.}
proc `=dup`*(source: Barrier): Barrier {.error.}

proc init*(b: out Barrier; parties: Natural) =
  b.required = parties
  b.left = parties
  b.cycle = 0
  initCond(b.c)
  initLock(b.L)

proc wait*(b: var Barrier) =
  acquire(b.L)
  dec b.left
  if b.left == 0:
    inc b.cycle
    b.left = b.required
    broadcast(b.c)
  else:
    let cycle = b.cycle
    while cycle == b.cycle:
      wait(b.c, b.L)
  release(b.L)

{.pop.}
