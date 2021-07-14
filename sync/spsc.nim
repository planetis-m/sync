import smartptrs, spsc_queue, std/isolation
export smartptrs, spsc_queue

type
  SpscSender*[T] = object
    queue*: SharedPtr[SpscQueue[T]]

#proc `=copy`*[T](dest: var SpscSender[T]; source: SpscSender[T]) {.error.}

proc newSpscSender*[T](queue: sink SharedPtr[SpscQueue[T]]): SpscSender[T] =
  result = SpscSender[T](queue: queue)

template trySend*(self: SpscSender, t: typed): bool =
  self.queue[].tryPush(t)

type
  SpscReceiver*[T] = object
    queue*: SharedPtr[SpscQueue[T]]

#proc `=copy`*[T](dest: var SpscReceiver[T]; source: SpscReceiver[T]) {.error.}

proc newSpscReceiver*[T](queue: sink SharedPtr[SpscQueue[T]]): SpscReceiver[T] =
  result = SpscReceiver[T](queue: queue)

template tryRecv*(self: SpscReceiver; dst: typed): bool =
  self.queue[].tryPop(dst)

proc newSpscChannel*[T](cap: int): (SpscSender[T], SpscReceiver[T]) =
  var p = isolate(newSpscQueue[T](cap))
  let queue = newSharedPtr[SpscQueue[T]](move p)
  result = (newSpscSender[T](queue), newSpscReceiver[T](queue))
