type
  Semaphore* = object
    c: Cond
    L: Lock
    counter: int

proc initSemaphore*(s: var Semaphore; value = 0) =
  initCond(s.c)
  initLock(s.L)
  s.counter = value

proc destroySemaphore*(s: var Semaphore) {.inline.} =
  deinitCond(s.c)
  deinitLock(s.L)

proc blockUntil*(s: var Semaphore) =
  acquire(s.L)
  while s.counter <= 0:
    wait(s.c, s.L)
  dec s.counter
  release(s.L)

proc blockUntil*(s: var Semaphore; tickets: int) =
  acquire(s.L)
  while s.counter <= tickets:
    wait(s.c, s.L)
  dec s.counter, tickets+1
  release(s.L)

proc signal*(s: var Semaphore) =
  acquire(s.L)
  inc s.counter
  signal(s.c)
  release(s.L)
