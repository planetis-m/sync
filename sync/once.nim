import std/locks, atomics2

{.push stackTrace: off.}

type
  Once* = object
    L: Lock
    finished: Atomic[bool]

proc init*(o: var Once) =
  bool(o.finished) = false
  initLock(o.L)

proc `=destroy`*(o: var Once) =
  deinitLock(o.L)

template once*(o: Once, body: untyped) =
  if not o.finished.load(Acquire):
    acquire(o.L)
    try:
      if not bool(o.finished):
        try:
          body
        finally:
          o.finished.store(true, Release)
    finally:
      release(o.L)

{.pop.}
