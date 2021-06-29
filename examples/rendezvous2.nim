import std/os, sync

const
  N = 2

var
  p: array[N, Thread[int]]
  fuel: int
  arrived: array[N, Semaphore]

template right: untyped = (i + 1) mod N

proc a(i: int) =
  wait arrived[right]
  echo "#", i, " observed fuel. Now left: ", fuel
  sleep(1000)

proc b(i: int) =
  echo "#", i, " filled with fuel..."
  fuel += 30
  signal arrived[i]
  sleep(2000)

proc main =
  #randomize()
  for i in 0 ..< N:
    init arrived[i]

  for i in 0 ..< N:
    if i mod 2 == 0:
      createThread(p[i], a, i)
    else: createThread(p[i], b, i)

  joinThreads(p)

main()
