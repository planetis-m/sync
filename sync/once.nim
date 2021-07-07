import atomics2

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
  if load(o.flag, Relaxed) == Incomplete and
      compareExchange(o.flag, expected, Running, Acquire, Relaxed):
    body
    store(o.flag, Complete, Release)
  else:
    while load(o.flag, Acquire) != Complete: cpuRelax()

{.pop.}
