====================================================
                        Sync
====================================================

Useful synchronization primitives.

Higher-level synchronization objects
====================================

The following is an overview of the available synchronization objects:

- *Barrier*: Ensures multiple threads will wait for each other to reach a point in the program, before continuing execution all together.
- *mpsc*: Multi-producer, single-consumer queues, used for message-based communication. Can provide a lightweight inter-thread synchronisation mechanism, at the cost of some extra memory.
- *spmc*: Single-producer, multi-consumer queues, used for message-based communication. Can provide a lightweight inter-thread synchronisation mechanism, at the cost of some extra memory.
- *Once*: Used for thread-safe, one-time initialization of a global variable.
- *RwLock*: Provides a mutual exclusion mechanism which allows multiple readers at the same time, while allowing only one writer at a time. In some cases, this can be more efficient than a mutex.
- *Semaphore*: Counting semaphore performing asynchronous permit aquisition.
- *Spinlock*: A mutual exclusion primitive useful for protecting shared data.

Acknowledgements
================

`Correctly implementing a spinlock in C++ <https://rigtorp.se/spinlock/>`_
`Jiffy: A Fast, Memory Efficient, Wait-Free Multi-Producers Single-Consumer Queue <https://arxiv.org/abs/2010.14189>`_
`Chase-Lev work stealing deque <https://arxiv.org/abs/2010.14189>`_
