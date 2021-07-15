when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

import sync/[atomics2, barrier, latch, once, rwlock, semaphore, smartptrs, spinlock, spsc, spsc_queue]
export atomics2, barrier, latch, once, rwlock, semaphore, smartptrs, spinlock, spsc, spsc_queue
