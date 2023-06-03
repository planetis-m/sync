#
#
#                                    Nim's Runtime Library
#        (c) Copyright 2021 Andreas Prell, Mamy André-Ratsimbazafy & Nim Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# Based on https://github.com/mratsim/weave/blob/5696d94e6358711e840f8c0b7c684fcc5cbd4472/unused/channels/channels_legacy.nim
# Those are translations of @aprell (Andreas Prell) original channels from C to Nim
# (https://github.com/aprell/tasking-2.0/blob/master/src/channel_shm/channel.c)
# And in turn they are an implementation of Michael & Scott lock-based queues
# (note the paper has 2 channels: lock-free and lock-based) with additional caching:
# Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms
# Maged M. Michael, Michael L. Scott, 1996
# https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf

import std/[locks, isolation], atomics2

# Channel (Shared memory channels)
# ----------------------------------------------------------------------------------

type
  ChannelRaw = ptr ChannelObj
  ChannelObj = object
    lock: Lock
    notFullCond, notEmptyCond: Cond
    closed: Atomic[bool]
    size: int
    itemsize: int # up to itemsize bytes can be exchanged over this channel
    head: int     # Items are taken from head and new items are inserted at tail
    tail: int
    buffer: ptr UncheckedArray[byte]
    counter: Atomic[int]

# ----------------------------------------------------------------------------------

proc numItems(chan: ChannelRaw): int {.inline.} =
  result = chan.tail - chan.head
  if result < 0:
    inc(result, 2 * chan.size)

  assert result <= chan.size

template isFull(chan: ChannelRaw): bool =
  abs(chan.tail - chan.head) == chan.size

template isEmpty(chan: ChannelRaw): bool =
  chan.head == chan.tail

# Unbuffered / synchronous channels
# ----------------------------------------------------------------------------------

template numItemsUnbuf(chan: ChannelRaw): int =
  chan.head

template isFullUnbuf(chan: ChannelRaw): bool =
  chan.head == 1

template isEmptyUnbuf(chan: ChannelRaw): bool =
  chan.head == 0

# ChannelRaw kinds
# ----------------------------------------------------------------------------------

proc isUnbuffered(chan: ChannelRaw): bool =
  chan.size - 1 == 0

# ChannelRaw status and properties
# ----------------------------------------------------------------------------------

proc isClosed(chan: ChannelRaw): bool {.inline.} = load(chan.closed, Relaxed)

proc peek(chan: ChannelRaw): int {.inline.} =
  (if chan.isUnbuffered: numItemsUnbuf(chan) else: numItems(chan))

# Channels memory ops
# ----------------------------------------------------------------------------------

proc allocChannel(size, n: int): ChannelRaw =
  result = cast[ChannelRaw](allocShared(sizeof(ChannelObj)))

  # To buffer n items, we allocate for n
  result.buffer = cast[ptr UncheckedArray[byte]](allocShared(n*size))

  initLock(result.lock)
  initCond(result.notFullCond)
  initCond(result.notEmptyCond)

  result.closed.store(false, Relaxed) # We don't need atomic here, how to?
  result.size = n
  result.itemsize = size
  result.head = 0
  result.tail = 0
  result.counter.store(0, Relaxed)

proc freeChannel(chan: ChannelRaw) =
  if chan.isNil:
    return

  if not chan.buffer.isNil:
    deallocShared(chan.buffer)

  deinitLock(chan.lock)
  deinitCond(chan.notFullCond)
  deinitCond(chan.notEmptyCond)

  deallocShared(chan)

# MPMC Channels (Multi-Producer Multi-Consumer)
# ----------------------------------------------------------------------------------

proc sendUnbufferedMpmc(chan: ChannelRaw, data: pointer, size: int, nonBlocking: bool): bool =
  if nonBlocking and chan.isFullUnbuf:
    return false

  acquire(chan.lock)

  if nonBlocking and chan.isFullUnbuf:
    # Another thread was faster
    release(chan.lock)
    return false

  while chan.isFullUnbuf:
    wait(chan.notFullcond, chan.lock)

  assert chan.isEmptyUnbuf
  assert size <= chan.itemsize
  copyMem(chan.buffer, data, size)

  chan.head = 1

  signal(chan.notEmptyCond)
  release(chan.lock)
  result = true

proc sendMpmc(chan: ChannelRaw, data: pointer, size: int, nonBlocking: bool): bool =
  assert not chan.isNil
  assert not data.isNil

  if isUnbuffered(chan):
    return sendUnbufferedMpmc(chan, data, size, nonBlocking)

  if nonBlocking and chan.isFull:
    return false

  acquire(chan.lock)

  if nonBlocking and chan.isFull:
    # Another thread was faster
    release(chan.lock)
    return false

  while chan.isFull:
    wait(chan.notFullcond, chan.lock)

  assert not chan.isFull
  assert size <= chan.itemsize

  let writeIdx = if chan.tail < chan.size: chan.tail
                 else: chan.tail - chan.size

  copyMem(addr chan.buffer[writeIdx * chan.itemsize], data, size)

  inc chan.tail
  if chan.tail == 2 * chan.size:
    chan.tail = 0

  signal(chan.notEmptyCond)
  release(chan.lock)
  result = true

proc recvUnbufferedMpmc(chan: ChannelRaw, data: pointer, size: int, nonBlocking: bool): bool =
  if nonBlocking and chan.isEmptyUnbuf:
    return false

  acquire(chan.lock)

  if nonBlocking and chan.isEmptyUnbuf:
    # Another thread was faster
    release(chan.lock)
    return false

  while chan.isEmptyUnbuf:
    wait(chan.notEmptyCond, chan.lock)

  assert chan.isFullUnbuf
  assert size <= chan.itemsize

  copyMem(data, chan.buffer, size)

  chan.head = 0

  signal(chan.notFullCond)
  release(chan.lock)
  result = true

proc recvMpmc(chan: ChannelRaw, data: pointer, size: int, nonBlocking: bool): bool =
  assert not chan.isNil
  assert not data.isNil

  if isUnbuffered(chan):
    return recvUnbufferedMpmc(chan, data, size, nonBlocking)

  if nonBlocking and chan.isEmpty:
    return false

  acquire(chan.lock)

  if nonBlocking and chan.isEmpty:
    # Another thread took the last data
    release(chan.lock)
    return false

  while chan.isEmpty:
    wait(chan.notEmptyCond, chan.lock)

  assert not chan.isEmpty
  assert size <= chan.itemsize

  let readIdx = if chan.head < chan.size: chan.head
                else: chan.head - chan.size

  copyMem(data, chan.buffer[readIdx * chan.itemsize].addr, size)

  inc chan.head
  if chan.head == 2 * chan.size:
    chan.head = 0

  signal(chan.notFullCond)
  release(chan.lock)
  result = true

# Public API
# ----------------------------------------------------------------------------------

type
  Chan*[T] = object ## Typed channels
    d: ChannelRaw

proc `=destroy`*[T](c: var Chan[T]) =
  if c.d != nil:
    if load(c.d.counter, Acquire) == 0:
      if c.d.buffer != nil:
        freeChannel(c.d)
    else:
      atomicDec(c.d.counter)

proc `=copy`*[T](dest: var Chan[T], src: Chan[T]) =
  ## Shares `Channel` by reference counting.
  if src.d != nil:
    atomicInc(src.d.counter)
  if dest.d != nil:
    `=destroy`(dest)
  dest.d = src.d

proc channelSend[T](chan: Chan[T], data: T, size: int, nonBlocking: bool): bool {.inline.} =
  ## Send item to the channel (FIFO queue)
  ## (Insert at last)
  sendMpmc(chan.d, addr data, size, nonBlocking)

proc channelReceive[T](chan: Chan[T], data: ptr T, size: int, nonBlocking: bool): bool {.inline.} =
  ## Receive an item from the channel
  ## (Remove the first item)
  recvMpmc(chan.d, data, size, nonBlocking)

proc trySend*[T](c: Chan[T], src: var Isolated[T]): bool {.inline.} =
  ## Sends item to the channel (non blocking).
  var data = src.extract
  result = channelSend(c, data, sizeof(data), true)
  if result:
    wasMoved(data)

template trySend*[T](c: Chan[T], src: T): bool =
  ## Helper templates for `trySend`.
  var p = isolate(src)
  trySend(c, p)

proc tryRecv*[T](c: Chan[T], dst: var T): bool {.inline.} =
  ## Receives item from the channel(non blocking).
  channelReceive(c, dst.addr, sizeof(dst), true)

proc send*[T](c: Chan[T], src: sink Isolated[T]) {.inline.} =
  ## Sends item to the channel(blocking).
  var data = src.extract
  #when defined(gcOrc) and defined(nimSafeOrcSend):
    #GC_runOrc()
  discard channelSend(c, data, sizeof(data), false)
  wasMoved(data)

template send*[T](c: Chan[T]; src: T) =
  ## Helper templates for `send`.
  var p = isolate(src)
  send(c, p)

proc recv*[T](c: Chan[T], dst: var T) {.inline.} =
  ## Receives item from the channel(blocking).
  discard channelReceive(c, dst.addr, sizeof(dst), false)

proc recvIso*[T](c: Chan[T]): Isolated[T] {.inline.} =
  var dst: T
  discard channelReceive(c, dst.addr, sizeof(dst), false)
  result = isolate(dst)

when false:
  proc open*[T](c: Chan[T]) {.inline.} =
    store(c.d.closed, false, Relaxed)

proc close*[T](c: Chan[T]) {.inline.} =
  store(c.d.closed, true, Relaxed)

proc peek*[T](c: Chan[T]): int {.inline.} = peek(c.d)

proc newChan*[T](elements = 30): Chan[T] =
  assert elements >= 1, "Elements must be positive!"
  result = Chan[T](d: allocChannel(sizeof(T), elements))
