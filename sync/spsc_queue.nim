# Nim port of https://github.com/rigtorp/SPSCQueue
import std/isolation, atomics2
from std/typetraits import supportsCopyMem

const
  cacheLineSize = 64

type
  SpscQueue*[T] = object
    cap: int
    data: ptr UncheckedArray[T]
    head, tail {.align(cacheLineSize).}: Atomic[int]
    # Padding to avoid adjacent allocations to share cache line with tail
    padding: array[cacheLineSize - sizeof(Atomic[int]), byte]

template Pad: untyped = (cacheLineSize - 1) div sizeof(T) + 1

proc `=destroy`*[T](this: var SpscQueue[T]) =
  if this.data != nil:
    when not supportsCopyMem(T):
      let head = this.head.load(Acquire)
      var tail = this.tail.load(Relaxed)
      while tail != head:
        `=destroy`(this.data[tail + Pad])
        inc tail
        if tail == this.cap:
          tail = 0
    deallocShared(this.data)

proc `=copy`*[T](dest: var SpscQueue[T]; source: SpscQueue[T]) {.error.}

proc init*[T](this: var SpscQueue[T]; capacity: Natural) =
  this.cap = capacity + 1
  this.data = cast[ptr UncheckedArray[T]](allocShared((this.cap + 2 * Pad) * sizeof(T)))

proc newSpscQueue*[T](cap: int): SpscQueue[T] =
  init(result, cap)

proc cap*[T](this: SpscQueue[T]): int = this.cap - 1

proc len*[T](this: SpscQueue[T]): int =
  result = this.head.load(Acquire) - this.tail.load(Acquire)
  if result < 0:
    result += this.cap

proc tryPush*[T](this: var SpscQueue[T]; value: var Isolated[T]): bool {.
    nodestroy.} =
  let head = this.head.load(Relaxed)
  var nextHead = head + 1
  if nextHead == this.cap:
    nextHead = 0
  if nextHead == this.tail.load(Acquire):
    result = false
  else:
    this.data[head + Pad] = extract value
    this.head.store(nextHead, Release)
    result = true

template tryPush*[T](this: SpscQueue[T]; value: T): bool =
  ## .. warning:: Using this template in a loop causes multiple evaluations of `value`.
  var p = isolate(value)
  tryPush(this, p)

proc tryPop*[T](this: var SpscQueue[T]; value: var T): bool =
  let tail = this.tail.load(Relaxed)
  if tail == this.head.load(Acquire):
    result = false
  else:
    value = move this.data[tail + Pad]
    var nextTail = tail + 1
    if nextTail == this.cap:
      nextTail = 0
    this.tail.store(nextTail, Release)
    result = true

when isMainModule:
  # Don't move this test
  proc testBasic =
    var r: SpscQueue[int]
    init(r, 100)
    for i in 0..<r.cap:
      # try to insert an element
      if r.tryPush(i):
        # succeeded
        discard
      else:
        # buffer full
        assert i == cap(r)
    for i in 0..<r.cap:
      # try to retrieve an element
      var value: int
      if r.tryPop(value):
        # succeeded
        discard
      else:
        # buffer empty
        assert i == cap(r)

  testBasic()
