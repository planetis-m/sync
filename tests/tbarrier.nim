import sync, std/[os, strformat]

const
  numThreads = 10
  numIters = 1_000

var
  barrier: Barrier
  phases: array[numThreads, int]
  threads: array[numThreads, Thread[int]]

proc routine(id: int) =
  for i in 0 ..< numIters:
    phases[id] = i
    if (id + i) mod numThreads == 0:
      sleep(5)
    wait barrier
    for j in 0 ..< numThreads:
      assert phases[j] == i, &"{id} in phase {i} sees {j} in phase {phases[j]}"
    wait barrier

proc testBarrier =
  initBarrier(barrier, numThreads)
  for i in 0 ..< numThreads:
    createThread(threads[i], routine, i)
  joinThreads(threads)

testBarrier()
