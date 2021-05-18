type
  RwLock* = object
    readPhase: Cond
    writePhase: Cond
    L: Lock
    counter: int # can be in three states: free = 0, reading > 0, writing = -1
    notMoved: bool

proc `=destroy`*(rw: var RwLock) =
  if rw.notMoved:
    deinitCond(rw.readPhase)
    deinitCond(rw.writePhase)
    deinitLock(rw.L)

proc `=sink`*(dest: var RwLock; source: RwLock) {.error.}
proc `=copy`*(dest: var RwLock; source: RwLock) {.error.}

proc init*(rw: var RwLock) =
  initCond rw.readPhase
  initCond rw.writePhase
  initLock rw.L
  rw.counter = 0
  rw.notMoved = true

proc beginRead*(rw: var RwLock) =
  acquire(rw.L)
  while rw.counter == -1:
    wait(rw.readPhase, rw.L)
  inc rw.counter
  release(rw.L)

proc beginWrite*(rw: var RwLock) =
  acquire(rw.L)
  while rw.counter != 0:
    wait(rw.writePhase, rw.L)
  rw.counter = -1
  release(rw.L)

proc endRead*(rw: var RwLock) =
  acquire(rw.L)
  dec rw.counter
  if rw.counter == 0:
    rw.writePhase.signal()
  release(rw.L)

proc endWrite*(rw: var RwLock) =
  acquire(rw.L)
  rw.counter = 0
  rw.readPhase.broadcast()
  rw.writePhase.signal()
  release(rw.L)

template read*(a: RwLock, body: untyped) =
  beginRead(a)
  try:
    body
  finally:
    endRead(a)

template write*(a: RwLock, body: untyped) =
  beginWrite(a)
  try:
    body
  finally:
    endWrite(a)
