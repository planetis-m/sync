#
#
#            Nim's Runtime Library
#        (c) Copyright 2023 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Latch for Nim.

runnableExamples:

  var data: array[10, int]
  var x: Latch
  init(x, 10)

  proc worker(i: int) =
    data[i] = 42
    x.leave()

  var threads: array[10, Thread[int]]
  for i in 0..<10:
    createThread(threads[i], worker, i)

  x.wait()
  for x in data:
    assert x == 42

  joinThreads(threads)


import std / locks

type
  Latch* = object
    ## A `Latch` is a synchronization object that can be used to `wait` until
    ## all workers have completed.
    c: Cond
    L: Lock
    counter: int

when defined(nimAllowNonVarDestructor):
  proc `=destroy`(x: Latch) {.inline.} =
    deinitCond(x.c)
    deinitLock(x.L)
else:
  proc `=destroy`(b: var Latch) {.inline.} =
    deinitCond(x.c)
    deinitLock(x.L)

proc `=sink`*(dest: var Latch; source: Latch) {.error.}
proc `=copy`*(dest: var Latch; source: Latch) {.error.}
proc `=dup`*(source: Latch): Latch {.error.}

proc init*(x: out Latch, count: Natural) =
  x.counter = count
  initCond(x.c)
  initLock(x.L)

proc dec*(x: var Latch) =
  ## Tells the `Latch` that one worker has finished its task.
  acquire(x.L)
  if x.counter > 0:
    dec x.counter
    if x.counter == 0:
      broadcast(x.c)
  release(x.L)

proc wait*(x: var Latch) =
  ## Waits until all workers have completed.
  acquire(x.L)
  while x.counter > 0:
    wait(x.c, x.L)
  release(x.L)
