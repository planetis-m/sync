import std/atomics

{.push stackTrace: off.}

type
  Once* = object
    flag: Atomic[int]

const
  Incomplete = 0
  Running = 1
  Complete = 2

template once*(o: Once, body: untyped) =
  var expected = Incomplete
  if load(o.flag, moRelaxed) == Incomplete and
      compareExchange(o.flag, expected, Running, moAcquire, moRelaxed):
    body
    store(o.flag, Complete, moRelease)
  else:
    while load(o.flag, moAcquire) != Complete: cpuRelax()

{.pop.}
