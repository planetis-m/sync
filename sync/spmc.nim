import fusion/smartptrs

type
  SpmcSender*[T] = object
    queue: SharedPtr[SpmcQueue[T]]

proc `=copy`*[T](dest: var SpmcSender[T]; source: SpmcSender[T]) {.error.}

proc newSpmcSender*[T](queue: sink SharedPtr[SpmcQueue[T]]): SpmcSender[T] =
  result = SpmcSender[T](queue: queue)

proc send*[T](self: SpmcSender[T], t: sink T) =
  self.queue[].push(t)

type
  SpmcReceiver*[T] = object
    queue: SharedPtr[SpmcQueue[T]]

proc newSpmcReceiver*[T](queue: sink SharedPtr[SpmcQueue[T]]): SpmcReceiver[T] =
  result = SpmcReceiver[T](queue: queue)

proc tryRecv*[T](self: SpmcReceiver[T]; dst: var T): bool =
  result = self.queue[].steal(dst)

proc newSpmcChannel*[T](): (SpmcSender[T], SpmcReceiver[T]) =
  let queue = newSharedPtr[SpmcQueue[T]](newSpmcQueue[T]())
  result = (newSpmcSender[T](queue), newSpmcReceiver[T](queue))
