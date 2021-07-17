# https://github.com/jaebeom/Implement_Thread_Synchronizers_For_POSIX
# create a set of threads to compute pi using numeric integration
import sync, std/[locks, strutils]

const
  numThreads = 4
  intervals = 50_000_000 # number of intervals to use for the numeric integration
  width = 1 / intervals # width of an interval

type
  WorkItem = tuple
    id: int
    split: int
    chunk: int

var
  L: Lock
  latch: Latch
  sum: float
  threads: array[numThreads, Thread[WorkItem]]

proc work(w: WorkItem) =
  var low: int # first interval to be processed
  var high: int # first interval not to be processed
  var localSum: float = 0 # sum for intervals being processed
  # compute low and high from the ID
  # (thread IDs less than split have one extra interval)
  if w.id < w.split:
    low = w.id * (w.chunk + 1)
    high = low + w.chunk + 1
  else:
    low = w.split * (w.chunk + 1) + (w.id - w.split) * w.chunk
    high = low + w.chunk
  # compute sum of the heights of the rectangles for the assigned intervals
  var x = (low.float + 0.5) * width # mid-point of an interval
  for i in low ..< high:
    localSum += 4 / (1 + x * x)
    x += width
  # update the shared sum
  acquire(L)
  sum += localSum
  release(L)
  # decrement the latch
  dec(latch)

proc pi =
  init latch, numThreads
  initLock L
  # compute how many intervals will each thread be responsible for
  # (thread IDs less than split have one extra interval)
  var chunk = intervals div numThreads
  var split = intervals mod numThreads
  if split == 0:
    split = numThreads
    dec chunk
  for i in 0 ..< numThreads:
    createThread(threads[i], work, (i, split, chunk))
  # wait on latch (for threads to finish)
  wait(latch)
  # to complete the computation of the area under the curve,
  # need to multiply by the width of an interval
  sum = sum * width
  echo sum.formatFloat(ffDecimal, 8)
  joinThreads(threads)

pi()
