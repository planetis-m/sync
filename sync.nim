when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

import sync/[atomics, barrier, latch, once, rwlock, semaphore]
export atomics, barrier, latch, once, rwlock, semaphore
