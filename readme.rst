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

API `documentation <https://planetis-m.github.io/sync/>`_
