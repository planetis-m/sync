import std/os, sync

const
  numThreads = 10
  numIters = 20

var
  threads: array[numThreads, Thread[void]]
  arrived = false
  event: Event

proc routine =
  for i in 0..<numIters:
    wait event
    assert arrived

proc main =
  #randomize()
  init event

  for i in 0..<numThreads:
    createThread(threads[i], routine)

  for i in 0..<numIters:
    arrived = true
    signal event
    sleep(1) # Prevent reset being called, before all threads have exited wait.
    reset event
    arrived = false

  joinThreads(threads)

main()
