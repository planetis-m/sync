import fusion/smartptrs

type
  MpscSender*[T] = object
    queue: SharedPtr[MpscQueue[T]]

proc newMpscSender*[T](queue: sink SharedPtr[MpscQueue[T]]): MpscSender[T] =
  result = MpscSender[T](queue: queue)

proc send*[T](self: MpscSender[T], t: sink T) =
  self.queue[].enqueue(t)

type
  MpscReceiver*[T] = object
    queue: SharedPtr[MpscQueue[T]]

proc `=copy`*[T](dest: var MpscReceiver[T]; source: MpscReceiver[T]) {.error.}

proc newMpscReceiver*[T](queue: sink SharedPtr[MpscQueue[T]]): MpscReceiver[T] =
  result = MpscReceiver[T](queue: queue)

proc tryRecv*[T](self: MpscReceiver[T]; dst: var T): bool =
  result = self.queue[].dequeue(dst)

proc newMpscChannel*[T](): (MpscSender[T], MpscReceiver[T]) =
  let queue = newSharedPtr[MpscQueue[T]](newMpscQueue[T]())
  result = (newMpscSender[T](queue), newMpscReceiver[T](queue))