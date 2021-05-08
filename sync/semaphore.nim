type
  Semaphore* = object
    c: Cond
    L: Lock
    value, wakeups: int

proc initSemaphore*(s: var Semaphore; value = 0) =
  initCond(s.c)
  initLock(s.L)
  s.value = value
  s.wakeups = 0

proc destroySemaphore*(s: var Semaphore) {.inline.} =
  deinitCond(s.c)
  deinitLock(s.L)

proc blockUntil*(s: var Semaphore) =
  acquire(s.L)
  dec s.value
  if s.value < 0:
    while true:
      wait(s.c, s.L)
      if s.wakeups >= 1: break
    dec s.wakeups
  release(s.L)

proc signal*(s: var Semaphore) =
  acquire(s.L)
  inc s.value
  if s.value <= 0:
    inc s.wakeups
    signal(s.c)
  release(s.L)
