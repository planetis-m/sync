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

proc initSemaphore*(s: var Semaphore; permits = 0) =
  s.counter = permits
  initCond(s.c)
  initLock(s.L)

proc acquire*(s: var Semaphore; permits: Positive = 1) =
  acquire(s.L)
  while s.counter < permits:
    wait(s.c, s.L)
  dec s.counter, permits
  release(s.L)

proc release*(s: var Semaphore; permits: Positive = 1) =
  acquire(s.L)
  inc s.counter, permits
  signal(s.c)
  release(s.L)
