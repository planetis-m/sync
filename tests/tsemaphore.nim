import sync

const
  bufSize = 10
  numIters = 100

var
  thr1, thr2: Thread[void]
  buf: array[bufSize, int]
  head, tail = 0
  chars, spaces: Semaphore

proc producer =
  for i in 0 ..< numIters:
    wait spaces
    assert buf[head] == 0
    buf[head] = i
    head = (head + 1) mod bufSize
    signal chars

proc consumer =
  for i in 0 ..< numIters:
    wait chars
    assert buf[tail] == i
    buf[tail] = 0
    tail = (tail + 1) mod bufSize
    signal spaces

proc rendezvous =
  initSemaphore chars
  initSemaphore spaces, bufSize

  createThread(thr1, producer)
  createThread(thr2, consumer)
  joinThread(thr1)
  joinThread(thr2)

rendezvous()
