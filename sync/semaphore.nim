type
  Semaphore* = object
    c: Cond
    L: Lock
    counter: int

proc initSemaphore*(s: var Semaphore; permits = 0) =
  initCond(s.c)
  initLock(s.L)
  s.counter = permits

proc destroySemaphore*(s: var Semaphore) =
  deinitCond(s.c)
  deinitLock(s.L)

proc blockUntil*(s: var Semaphore; permits: Positive = 1) =
  acquire(s.L)
  while s.counter < permits:
    wait(s.c, s.L)
  dec s.counter, permits
  release(s.L)

proc signal*(s: var Semaphore; permits: Positive = 1) =
  acquire(s.L)
  inc s.counter, permits
  signal(s.c)
  release(s.L)
