import sync/spsc, std/isolation, std/strutils

const
  bufCap = 20

type
  Node {.acyclic.} = ref object
    name: string
    kids: seq[Node]
    parent {.cursor.}: Node

proc initParents(tree: Node) =
  for kid in items(tree.kids):
    kid.parent = tree
    initParents(kid)

proc walk(tree: Node, action: proc (node: Node, depth: int), depth = 0) =
  action(tree, depth)
  for kid in items(tree.kids):
    walk(kid, action, depth + 1)

proc print(tree: Node) =
  walk(tree, proc (node: Node, depth: int) =
    echo repeat(' ', 2 * depth), node.name
  )

proc calcTotalDepth(tree: Node): int =
  var total = 0
  walk(tree, proc (_: Node, depth: int) =
    total += depth
  )
  return total

proc create(intro: sink Node): Node =
  result = Node(name: "root", kids: @[
    intro,
    Node(name: "one", kids: @[
      Node(name: "two"),
      Node(name: "three"),
    ]),
    Node(name: "four"),
  ])
  initParents(result)
  var internalIntro = result.kids[0]
  result.kids.add(Node(name: "outro"))
  print internalIntro
  print result
  # GC_runOrc()

proc process(tree: sink Node) =
  var totalDepth = 0
  for i in 0 ..< 100:
    totalDepth += calcTotalDepth(tree)
  echo "Total depth: ", totalDepth

type
  WorkerKind = enum
    Producer
    Consumer

  ThreadArgs = object
    case id: WorkerKind
    of Producer:
      tx: SpscSender[Node]
    of Consumer:
      rx: SpscReceiver[Node]

template sendLoop(tx, data: typed, body: untyped): untyped =
  while not tx.trySend(data):
    body

template recvLoop(rx, data: typed, body: untyped): untyped =
  while not rx.tryRecv(data):
    body

proc threadFn(args: ThreadArgs) {.thread.} =
  case args.id
  of Consumer:
    var res: Node
    recvLoop(args.rx, res): cpuRelax()
    process(res)
  of Producer:
    var intro = Node(name: "intro")
    var p = unsafeIsolate(create(move intro)) # error expression cannot be isolated
    sendLoop(args.tx, p): cpuRelax()
    # echo intro.parent.name

proc testSpScRing =
  let (tx, rx) = newSpscChannel[Node](bufCap) # tx for transmission, rx for receiving
  var thr1, thr2: Thread[ThreadArgs]
  createThread(thr1, threadFn, ThreadArgs(id: Producer, tx: tx))
  createThread(thr2, threadFn, ThreadArgs(id: Consumer, rx: rx))
  joinThread(thr1)
  joinThread(thr2)

testSpScRing()
