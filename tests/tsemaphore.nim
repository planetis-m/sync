import sync

var
  aThread, bThread: Thread[void]
  aArrived, bArrived: Semaphore

proc a =
  echo "A starts"
  release aArrived
  acquire bArrived
  echo "A progresses"

proc b =
  echo "B starts"
  release bArrived
  acquire aArrived
  echo "B progresses"

proc rendezvous =
  initSemaphore aArrived
  initSemaphore bArrived

  createThread(aThread, b)
  createThread(bThread, a)
  joinThread(aThread)
  joinThread(bThread)

rendezvous()
