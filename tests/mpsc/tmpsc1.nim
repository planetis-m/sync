import sync

const
  numThreads = 8
  numMsgs = 1000

var
  p: array[numThreads, Thread[void]]
  q: MpscQueue[int]

proc threadFn =
  for i in 0..<numMsgs:
    q.enqueue(i)

proc multiThreadedChannel =
  q = newMpscQueue[int]()
  for i in 0..<numThreads:
    createThread(p[i], threadFn)
  let expected = (var sum = 0; for i in 0..<1_000: sum += i; sum) * numThreads
  var s = 0
  while true:
    var data: int
    while not q.dequeue(data): cpuRelax()
    s += data
    if s >= expected: break
  assert s == expected
  joinThreads(p)

multiThreadedChannel()
