import std/os, sync

const
  N = 4

var
  p: array[N, Thread[int]]
  arrived: Semaphore

proc a(i: int) =
  echo i, " starts"
  wait arrived
  sleep(1000)
  echo i, " progresses"
  signal arrived

proc main =
  #randomize()
  initSem arrived, 2
  for i in 0 ..< N:
    createThread(p[i], a, i)
  joinThreads(p)

main()
