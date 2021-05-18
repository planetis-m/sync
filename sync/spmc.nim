import fusion/smartptrs, std/isolation

type
  SpmcSender*[T] = object
    queue: SharedPtr[SpmcQueue[T]]

proc `=copy`*[T](dest: var SpmcSender[T]; source: SpmcSender[T]) {.error.}

proc newSpmcSender*[T](queue: sink SharedPtr[SpmcQueue[T]]): SpmcSender[T] =
  result = SpmcSender[T](queue: queue)

proc send*[T](self: SpmcSender[T], t: sink Isolated[T]) {.inline.} =
  self.queue[].push(t.extract)

template send*[T](self: SpmcSender[T], t: T) =
  send(self, isolate(t))

type
  SpmcReceiver*[T] = object
    queue: SharedPtr[SpmcQueue[T]]

proc newSpmcReceiver*[T](queue: sink SharedPtr[SpmcQueue[T]]): SpmcReceiver[T] =
  result = SpmcReceiver[T](queue: queue)

proc tryRecv*[T](self: SpmcReceiver[T]; dst: var T): bool {.inline.} =
  result = self.queue[].steal(dst)

proc newSpmcChannel*[T](): (SpmcSender[T], SpmcReceiver[T]) =
  let queue = newSharedPtr[SpmcQueue[T]](newSpmcQueue[T]())
  result = (newSpmcSender[T](queue), newSpmcReceiver[T](queue))
