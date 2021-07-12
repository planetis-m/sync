when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

import sync/[atomics2, barrier, once, rwlock, semaphore, smartptrs, spinlock]
export atomics2, barrier, once, rwlock, semaphore, smartptrs, spinlock
