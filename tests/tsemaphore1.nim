import sync

const
  N = 4

var
  p: array[N, Thread[void]]
  arrived: Semaphore

proc a =
  echo getThreadId(), " starts"
  acquire arrived
  echo getThreadId(), " progresses"
  release arrived

proc multiplex =
  initSemaphore arrived, 2
  for i in 0 ..< N:
    createThread(p[i], a)
  joinThreads(p)

multiplex()
