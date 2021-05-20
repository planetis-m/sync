import std / locks

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

{.push stackTrace: off.}

include sync/barrier
include sync/once
include sync/rwlock
include sync/semaphore
include sync/spinlock
when false: include sync/spmc_queue
include sync/mpsc_queue
when false: include sync/spmc
when false: include sync/mpsc

{.pop.}
