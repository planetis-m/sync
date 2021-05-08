import os, sync

const
  numIters = 200

var
  pong: Thread[void]
  q1: SpmcQueue[int]
  q2: SpmcQueue[int]

proc pongFn {.thread.} =
  while true:
    var n: int
    while not q1.steal(n): cpuRelax()
    q2.push(n)
    #sleep 200
    if n == 0: break

proc pingPong =
  q1 = newSpmcQueue[int]()
  q2 = newSpmcQueue[int]()
  createThread(pong, pongFn)
  for i in 1..numIters:
    q1.push(9091_89)
    var n: int
    #sleep 100
    while not q2.steal(n): cpuRelax()
  q1.push(0)
  var n: int
  while not q2.steal(n): cpuRelax()
  pong.joinThread()

pingPong()
