import mpsc

const
  nthreads = 8
  nmsgs = 1000

var
  p: array[nthreads, Thread[Sender[int]]]

proc threadFn(tx: Sender[int]) =
  for i in 0..<nmsgs:
    tx.send(i)

proc multiThreadedChannel =
  let (tx, rx) = newChannel[int]()
  for i in 0..<nthreads:
    createThread(p[i], threadFn, tx)
  joinThreads(p)
  var
    s = 0
    data = 0
  while rx.tryRecv(data):
    s += data
  let expected = (var sum = 0; for i in 0..<1_000: sum += i; sum) * nthreads
  assert s == expected

multiThreadedChannel()
