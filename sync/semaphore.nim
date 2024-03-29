import std/locks

{.push stackTrace: off.}

type
  Semaphore* = object
    c: Cond
    L: Lock
    counter: int

proc `=destroy`*(s: var Semaphore) =
  deinitCond(s.c)
  deinitLock(s.L)

proc `=sink`*(dest: var Semaphore; source: Semaphore) {.error.}
proc `=copy`*(dest: var Semaphore; source: Semaphore) {.error.}
proc `=dup`*(source: Semaphore): Semaphore {.error.}

proc init*(s: out Semaphore; count = 0) =
  s.counter = count
  initCond(s.c)
  initLock(s.L)

proc wait*(s: var Semaphore) =
  acquire(s.L)
  while s.counter <= 0:
    wait(s.c, s.L)
  dec s.counter
  release(s.L)

proc signal*(s: var Semaphore) =
  acquire(s.L)
  inc s.counter
  signal(s.c)
  release(s.L)

{.pop.}
