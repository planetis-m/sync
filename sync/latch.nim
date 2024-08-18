import std/locks

type
  Latch* = object
    c: Cond
    L: Lock
    counter: int

proc `=destroy`*(x: var Latch) =
  deinitCond(x.c)
  deinitLock(x.L)

proc `=sink`*(dest: var Latch; source: Latch) {.error.}
proc `=copy`*(dest: var Latch; source: Latch) {.error.}
proc `=dup`*(source: Latch): Latch {.error.}

proc createLatch*(count: Natural = 0): Latch =
  result = default(Latch)
  result.counter = count
  initCond(result.c)
  initLock(result.L)

proc dec*(x: var Latch) =
  acquire(x.L)
  if x.counter > 0:
    dec x.counter
    if x.counter == 0:
      broadcast(x.c)
  release(x.L)

proc wait*(x: var Latch) =
  acquire(x.L)
  while x.counter > 0:
    wait(x.c, x.L)
  release(x.L)
