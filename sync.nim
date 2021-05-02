import std / locks

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

{.push stackTrace: off.}

include sync/arc
include sync/barrier
include sync/once
include sync/rwmonitor
include sync/semaphore
include sync/spinlock
when false: include sync/mpsc

{.pop.}
