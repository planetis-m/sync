when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

import sync/atomics2
import sync/barrier
import sync/once
import sync/rwlock
import sync/semaphore
import sync/spinlock

export atomics2, barrier, once, rwlock, semaphore, spinlock
