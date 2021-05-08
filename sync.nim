import std / locks

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

{.push stackTrace: off.}

include sync/barrier
include sync/once
include sync/rwmonitor
include sync/semaphore
include sync/spinlock
include sync/spmc
include sync/mpsc
when false sync/mpsc_channel

{.pop.}
