import std / math
from typetraits import supportsCopyMem

# Chase-Lev work stealing deque
#
# Dynamic Circular Work-Stealing Deque
# http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.170.1097&rep=rep1&type=pdf
#
# Correct and Efﬁcient Work-Stealing for Weak Memory Models
# http://www.di.ens.fr/~zappa/readings/ppopp13.pdf

const
  defaultInitialSize = 32
  cacheLineSize = 64

type
  SpmcQueue*[T] = object
    top {.align(cacheLineSize).}: int
    bottom {.align(cacheLineSize).}: int
    p {.align(cacheLineSize).}: ptr Buffer[T]

  Buffer[T] = object
    previous: ptr Buffer[T]
    mask: int
    data: UncheckedArray[T]

template align(address, alignment): untyped = (address + (alignment - 1)) and not (alignment - 1)
template load(p, order): untyped = atomicLoadN(addr p, order)
template store(p, val, order): untyped = atomicStoreN(addr p, val, order)

proc `=destroy`[T](self: var SpmcQueue[T]) =
  var x = self.p
  when not supportsCopyMem(T):
    for i in self.top ..< self.bottom: `=destroy`(x.data[i])
  while x != nil:
    let nx = x.previous
    alignedDealloc(x, alignof(T))
    x = nx

proc newBuffer[T](cap = defaultInitialSize): ptr Buffer[T] =
  assert isPowerOfTwo(cap), " length must be a power of two"
  result = cast[ptr Buffer[T]](alignedAlloc0(align(sizeof(Buffer[T]), alignof(T)) + cap * sizeof(T), alignof(T)))
  result.mask = cap - 1

proc `[]`*[T](self: ptr Buffer[T], idx: Natural): T =
  let idx = idx and self.mask
  result = move(self.data[idx])

proc `[]=`*[T](self: ptr Buffer[T], idx: Natural, value: sink T) =
  let idx = idx and self.mask
  self.data[idx] = value

proc cap*[T](self: ptr Buffer[T]): int {.inline.} =
  result = self.mask + 1

proc grow[T](self: ptr Buffer[T], top, bottom: int): ptr Buffer[T] =
  # Growing the array returns a new circular_array object and keeps a
  # linked list of all previous arrays. This is done because other threads
  # could still be accessing elements from the smaller arrays.
  result = newBuffer[T](self.cap * 2)
  result.previous = self
  for i in top ..< bottom:
    result[i] = self[i]

proc newSpmcQueue*[T](): SpmcQueue[T] =
  # top and bottom must start at 1, otherwise, the first Pop on an empty queue will underflow self.bottom
  result = SpmcQueue[T](top: 1, bottom: 1, p: newBuffer[T]())

proc push*[T](self: var SpmcQueue[T]; value: sink T) =
  let b = self.bottom.load(AtomicRelaxed)
  let t = self.top.load(AtomicAcquire)
  var p = self.p.load(AtomicRelaxed)
  if b - t > p.cap - 1:
    # Full queue.
    p = p.grow(t, b)
    self.p.store(p, AtomicRelease)
  p[b] = value
  when defined(StrongMemoryModel):
    atomicSignalFence(AtomicRelease)
  else:
    atomicThreadFence(AtomicRelease)
  self.bottom.store(b + 1, AtomicRelaxed)

proc pop*[T](self: var SpmcQueue[T]; value: var T): bool =
  let b = self.bottom.load(AtomicRelaxed) - 1
  let p = self.p.load(AtomicRelaxed)
  self.bottom.store(b, AtomicRelaxed)
  atomicThreadFence(AtomicSeqCst)
  let t = self.top.load(AtomicRelaxed)
  result = true
  if t <= b:
    # Non-empty queue.
    value = p[b]
    if t == b:
      # Single last element in queue.
      if not atomicCompareExchangeN(addr self.top, unsafeAddr t, t + 1, false, AtomicSeqCst, AtomicRelaxed):
        # Failed race.
        result = false
      self.bottom.store(b + 1, AtomicRelaxed)
  else:
    # Empty queue.
    result = false
    self.bottom.store(b + 1, AtomicRelaxed)

proc steal*[T](self: var SpmcQueue[T]; value: var T): bool =
  let t = self.top.load(AtomicAcquire)
  when defined(StrongMemoryModel):
    atomicSignalFence(AtomicSeqCst)
  else:
    atomicThreadFence(AtomicSeqCst)
  let b = self.bottom.load(AtomicAcquire)
  if t < b:
    # Non-empty queue.
    let p = self.p.load(AtomicConsume)
    value = p[t]
    result = atomicCompareExchangeN(addr self.top, unsafeAddr t, t + 1, false, AtomicSeqCst, AtomicRelaxed)
  else: result = false

when isMainModule:
  import os

  const
    numIters = 200

  var
    pong: Thread[void]
    q1: SpmcQueue[int]
    q2: SpmcQueue[int]

  proc pongFn {.thread.} =
    while true:
      var n: int
      while not q1.steal(n): cpuRelax()
      q2.push(n)
      #sleep 200
      if n == 0: break

  proc pingPong =
    q1 = newSpmcQueue[int]()
    q2 = newSpmcQueue[int]()
    createThread(pong, pongFn)
    for i in 1..numIters:
      q1.push(9091_89)
      var n: int
      #sleep 100
      while not q2.steal(n): cpuRelax()
    q1.push(0)
    var n: int
    while not q2.steal(n): cpuRelax()
    pong.joinThread()

  pingPong()
