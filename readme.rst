====================================================
                        Sync
====================================================

Useful synchronization primitives.

Higher-level synchronization objects
====================================

The following is an overview of the available synchronization objects:

- *Barrier*: Ensures multiple threads will wait for each other to reach a point in the program, before continuing execution all together.
- *Once*: Used for thread-safe, one-time initialization of a global variable.
- *RwLock*: Provides a mutual exclusion mechanism which allows multiple readers at the same time, while allowing only one writer at a time. In some cases, this can be more efficient than a mutex.
- *Semaphore*: Counting semaphore performing asynchronous permit aquisition.
- *Spinlock*: A mutual exclusion primitive useful for protecting shared data.

API `documentation <https://planetis-m.github.io/sync/>`_

Acknowledgements
================

- `Correctly implementing a spinlock in C++ <https://rigtorp.se/spinlock/>`_
- `SPSCQueue.h <https://github.com/rigtorp/SPSCQueue>`_ A bounded single-producer
  single-consumer wait-free and lock-free queue written in C++11, Erik Rigtorp
