type
  SpinLock* = object
    lock: bool

proc acquire*(s: var SpinLock) =
  while true:
    if not atomicExchangeN(addr s.lock, true, AtomicAcquire):
      return
    else:
      while atomicLoadN(addr s.lock, AtomicRelaxed): cpuRelax()

proc tryAcquire*(s: var SpinLock): bool =
  result = not atomicLoadN(addr s.lock, AtomicRelaxed) and
      not atomicExchangeN(addr s.lock, true, AtomicAcquire)

proc release*(s: var SpinLock) =
  atomicStoreN(addr s.lock, false, AtomicRelease)

template withLock*(a: SpinLock, body: untyped) =
  acquire(a)
  try:
    body
  finally:
    release(a)
