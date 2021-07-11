import std/os, sync

const
  numIters = 100
  numThreads = 10

var
  threads: array[numThreads, Thread[int]]
  event: Event
  sem: Semaphore

proc routine(id: int) =
  for i in 0..<numIters:
    signal sem
    if (id + i) mod numThreads == 0:
      sleep 1
    wait event

proc main =
  #randomize()
  init event
  init sem
  for i in 0..<numThreads:
    createThread(threads[i], routine, i)

  for i in 0..<numIters:
    signal event
    wait sem, numThreads
    reset event
  signal event

  joinThreads(threads)

main()
