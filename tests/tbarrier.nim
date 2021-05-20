import sync, std/[os, strformat]

const
  maxThreads = 6
  numIters = 1000

var
  barrier: Barrier
  sequence: array[maxThreads, int]
  threads: array[maxThreads, Thread[(int, int)]]

proc routine(data: (int, int)) =
  let (numThreads, me) = data
  for i in 0 ..< numIters:
    if me < numThreads:
      sequence[me] = i
      # Delay each thread; could randonly delay all threads if we think
      # specific ordering or a more subtle race is a problem.
      if me mod numThreads == 0:
        sleep(1) # todo: random
      barrier.wait()
      for j in 0 ..< numThreads:
        assert sequence[j] == i, &"{me} in phase {i} sees {j} in phase {sequence[j]}"
      barrier.wait()

proc checkBarrier(numThreads: int) =
  initBarrier(barrier, numThreads)
  for i in 0 ..< maxThreads:
    sequence[i] = 0
  for i in 0 ..< maxThreads:
    createThread(threads[i], routine, (numThreads, i))
  joinThreads(threads)
  `=destroy`(barrier)

proc testBarrier =
  for i in 2 .. maxThreads:
    checkBarrier(i)

testBarrier()
