import std/atomics

{.push stackTrace: off.}

type
  SpinLock* = object
    lock: Atomic[bool]

proc acquire*(s: var SpinLock) =
  while true:
    if not s.lock.exchange(true, moAcquire):
      return
    else:
      while s.lock.load(moRelaxed): cpuRelax()

proc tryAcquire*(s: var SpinLock): bool =
  result = not s.lock.load(moRelaxed) and
      not s.lock.exchange(true, moAcquire)

proc release*(s: var SpinLock) =
  s.lock.store(false, moRelease)

template withLock*(a: SpinLock, body: untyped) =
  acquire(a)
  try:
    body
  finally:
    release(a)

{.pop.}
