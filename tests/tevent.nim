import std/os, sync

const
  numThreads = 10

var
  threads: array[numThreads, Thread[void]]
  arrived = false
  event: Event

proc routine =
  wait event
  assert arrived

proc main =
  #randomize()
  init event
  for i in 0..<numThreads:
    createThread(threads[i], routine)
  # Signaling threads
  arrived = true
  signal event
  joinThreads(threads)

main()
