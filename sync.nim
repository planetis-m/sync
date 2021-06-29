when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

{.push stackTrace: off.}

import sync/barrier
import sync/once
import sync/rwlock
import sync/semaphore
import sync/spinlock

export barrier, once, rwlock, semaphore, spinlock

{.pop.}
