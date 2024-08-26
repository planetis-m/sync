when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

import sync/[barrier, latch, once, rwlock, semaphore]
export barrier, latch, once, rwlock, semaphore
