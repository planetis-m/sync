type
  Once* = object
    L: Lock
    finished: bool

proc initOnce*(o: var Once) =
  initLock(o.L)
  o.finished = false

proc destroyOnce*(o: var Once) {.inline.} =
  deinitLock(o.L)

template once*(o: Once, body: untyped) =
  if not atomicLoadN(addr o.finished, AtomicAcquire):
    acquire(o.L)
    try:
      if not o.finished:
        try:
          body
        finally:
          atomicStoreN(addr o.finished, true, AtomicRelease)
    finally:
      release(o.L)
