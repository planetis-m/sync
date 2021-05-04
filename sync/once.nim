type
  Once* = distinct int

const
  Incomplete = 0
  Running = 1
  Complete = 2

template once*(o: Once, body: untyped) =
  let notCalled = Incomplete
  if atomicCompareExchangeN(addr o.int, unsafeAddr notCalled,
      Running, false, AtomicRelease, AtomicRelaxed):
    body
    atomicStoreN(addr o.int, Complete, AtomicRelease)
  else:
    while atomicLoadN(addr o.int, AtomicAcquire) != Complete: cpuRelax()
