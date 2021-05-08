=================================================================
                        Sync
=================================================================

Useful synchronization primitives.

Higher-level synchronization objects
====================================

The following is an overview of the available synchronization objects:

- *Barrier*: Ensures multiple threads will wait for each other to reach a point in the program, before continuing execution all together.
- *mpsc*: Multi-producer, single-consumer queues, used for message-based communication. Can provide a lightweight inter-thread synchronisation mechanism, at the cost of some extra memory.
- *spmc*: Single-producer, multi-consumer queues, used for message-based communication. Can provide a lightweight inter-thread synchronisation mechanism, at the cost of some extra memory.
- *Once*: Used for thread-safe, one-time initialization of a global variable.
- *RwMonitor*: Provides a mutual exclusion mechanism which allows multiple readers at the same time, while allowing only one writer at a time. In some cases, this can be more efficient than a mutex.
- *Semaphore*: Counting semaphore performing asynchronous permit aquisition.
- *Spinlock*: A mutual exclusion primitive useful for protecting shared data
