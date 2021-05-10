import sync

const
  numThreads = 10
  maxIters = 1000

type
  Singleton = object
    data: int

var
  threads: array[numThreads, Thread[void]]
  counter = 0
  instance: Singleton
  o: Once

proc getInstance(): ptr Singleton =
  once(o):
    instance = Singleton(data: counter)
    inc counter
  result = addr instance

proc routine {.thread.} =
  for i in 1 .. maxIters:
    assert getInstance().data == 0

proc main =
  for i in 0 ..< numThreads:
    createThread(threads[i], routine)
  joinThreads(threads)

main()
