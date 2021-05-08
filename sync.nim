import std / locks

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

{.push stackTrace: off.}

include sync/barrier
include sync/once
include sync/rwmonitor
include sync/semaphore
include sync/spinlock
include sync/spmc_queue
include sync/mpsc_queue
when false: sync/spmc
when false: sync/mpsc

{.pop.}
