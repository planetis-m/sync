# https://www.youtube.com/watch?v=MDgVJVIRBnM
import std / [random, os, strformat], sync

const
  numThreads = 8

var
  p: array[numThreads, Thread[int]]
  diceValues: array[numThreads, int]
  status: array[numThreads, bool]

  barrierRolledDice: Barrier
  barrierCalculated: Barrier

proc roll(i: int) =
  while true:
    diceValues[i] = rand(1 .. 6)
    #sleep(1000)
    wait barrierRolledDice
    wait barrierCalculated
    if status[i]:
      echo &"({i} rolled {diceValues[i]}) I won"
    else:
      echo &"({i} rolled {diceValues[i]}) I lost"

proc main =
  #randomize()
  init barrierRolledDice, numThreads+1
  init barrierCalculated, numThreads+1

  for i in 0 ..< numThreads:
    createThread(p[i], roll, i)

  while true:
    wait barrierRolledDice
    echo("==== New round started ====")
    # Calculate winner
    var maxRoll = diceValues[0]
    for i in 1 ..< numThreads:
      if diceValues[i] > maxRoll:
        maxRoll = diceValues[i]
    for i in 0 ..< numThreads:
      status[i] = diceValues[i] == maxRoll
    #sleep(1000)
    wait barrierCalculated

  joinThreads(p)

main()
