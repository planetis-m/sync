## Jiffy
##
## Jiffy is an unbounded, wait-free, multi-producer-single-consumer queue.
##
## It's a Nim port of [Jiffy](https:#github.com/DolevAdas/Jiffy)
## which is implemented in C++ and described in [this arxiv paper](https:#arxiv.org/abs/2010.14189).
## Presentation: https://www.youtube.com/watch?v=IO7ju-CEkNs
## Many thanks to the developers of the Rust [port](https://github.com/s1ck/riffy), which this lib is based on.
from typetraits import supportsCopyMem

const
  BufferSize = 1620 # The number of nodes within a single buffer.

type
  State = range[0'u8..2'u8] # Represent the state of a node within a buffer.

const
  Empty = 0'u8   # Initial state, the node contains no data.
  Set = 1'u8     # The enqueue process was successful, the node contains data.
  Handled = 2'u8 # The dequeue process was successful, the node contains no data.

# A node is contained in a `BufferList` and owns
# the actual data that has been enqueued. A node
# has a state which is updated during enqueue and
# dequeue operations.
type
  Node[T] = object
    pdata: T
    # The state of the node needs to be atomic to make
    # state changes visible to the dequeue thread.
    isSet: State

proc state[T](n: Node[T]): State {.inline.} =
  result = atomicLoadN(unsafeAddr n.isSet, AtomicAcquire)

proc setState[T](n: var Node[T], state: State) {.inline.} =
  atomicStoreN(addr n.isSet, state, AtomicRelease)

proc data[T](n: var Node[T]): T {.inline.} =
  # Read the data from the candidate node.
  result = move(n.pdata)
  setState n, Handled

proc setData[T](n: var Node[T], data: sink T) {.inline, nodestroy.} =
  # Load the given data into the node and change its state to `Set`.
  n.pdata = data
  setState n, Set

# The buffer list holds a fixed number of nodes.
# Buffer lists are connected with each other and
# form a linked list. Enqueue operations always
# append to the linked list by creating a new buffer
# and atomically updating the `next` pointer of the
# last buffer list in the queue.
type
  BufferList[T] = object
    # A fixed size vector of nodes that hold the data.
    nodes: array[BufferSize, Node[T]]
    # A pointer to the previous buffer list.
    prev: ptr BufferList[T]
    # An atomic pointer to the next buffer list.
    next: ptr BufferList[T]
    # The position to read the next element from inside
    # the buffer list. The head index is only updated
    # by the dequeue thread.
    head: int
    # The position of that buffer list in the queue.
    # That index is used to compute the number of elements
    # previously added to the queue.
    pos: int

proc newBufferList[T](positionInQueue: Natural = 1,
    prev: ptr BufferList[T] = nil): ptr BufferList[T] =
  result = createShared(BufferList[T])
  result.prev = prev
  result.pos = positionInQueue

template createBuffer(buffer): untyped = newBufferList(buffer.pos + 1, buffer)
template sizeWithoutBuffer(buffer): untyped = BufferSize * (buffer.pos - 1)

type
  MpscQueue*[T] = object ## A multi-producer-single-consumer queue.
    headOfQueue: ptr BufferList[T]
    tailOfQueue: ptr BufferList[T] # atomic
    tail: int # atomic

proc `=destroy`*[T](x: var MpscQueue[T]) =
  var tempBuffer = x.headOfQueue
  while tempBuffer != nil:
    when not supportsCopyMem(T):
      template head: untyped = tempBuffer.head
      let tempTail = atomicLoadN(addr x.tailOfQueue, AtomicSeqCst)
      let prevSize = sizeWithoutBuffer(tempTail)
      let headIsTail = tempBuffer == tempTail
      let headIsEmpty = head == atomicLoadN(addr x.tail, AtomicAcquire) - prevSize
      echo "head: ", head
      echo "size: ", x.tail - prevSize
      echo "headIsTail: ", headIsTail, ", headIsEmpty: ", headIsEmpty
      if headIsTail and headIsEmpty:
        discard
      else:
        var count = 0
        for i in head ..< BufferSize: # non-deterministic code
          count.inc
          if tempBuffer.nodes[i].state == Set:
            echo "destroy ", tempBuffer.nodes[i].pdata
            `=destroy`(tempBuffer.nodes[i].pdata)
        echo "count ", count
    let next = atomicLoadN(addr tempBuffer.next, AtomicAcquire)
    deallocShared(tempBuffer)
    tempBuffer = next

proc `=copy`*[T](dest: var MpscQueue[T]; source: MpscQueue[T]) {.error.}

proc newMpscQueue*[T](): MpscQueue[T] =
  let headOfQueue = newBufferList[T]()
  result = MpscQueue[T](
    headOfQueue: headOfQueue,
    tailOfQueue: headOfQueue,
    tail: 0
  )

proc insert[T](self: var MpscQueue[T], data: sink T,
    index: int, buffer: ptr BufferList[T], isLastBuffer: bool) =
  # Insert the element at the right index. This also atomically
  # sets the state of the node to SET to make that change
  # visible to the dequeue thread.
  setData(buffer.nodes[index], data)
  # Optimization to reduce contention on the tail of the queue.
  # If the inserted element is the second entry in the
  # current buffer, we already allocate a new buffer and
  # append it to the queue.
  if index == 1 and isLastBuffer:
    let newBuffer = createBuffer(buffer)
    var nilPtr: ptr BufferList[T]
    if not atomicCompareExchangeN(addr buffer.next, addr nilPtr,
        newBuffer, false, AtomicSeqCst, AtomicSeqCst):
      deallocShared(newBuffer)

proc enqueue*[T](self: var MpscQueue[T], data: sink T) =
  # Retrieve an index where we insert the new element.
  # Since this is called by multiple enqueue threads,
  # the generated index can be either past or before
  # the current tail buffer of the queue.
  let location = atomicFetchAdd(addr self.tail, 1, AtomicSeqCst)
  # Track if the element is inserted in the last buffer.
  var isLastBuffer = true
  while true:
    # The buffer in which we eventually insert into.
    var tempTail = atomicLoadN(addr self.tailOfQueue, AtomicAcquire)
    # The number of items in the queue without the current buffer.
    var prevSize = sizeWithoutBuffer(tempTail)
    # The location is in a previous buffer. We need to track back to that one.
    while location < prevSize:
      isLastBuffer = false
      tempTail = tempTail.prev
      prevSize -= BufferSize
    # The current capacity of the queue.
    let globalSize = BufferSize + prevSize
    if prevSize <= location and location < globalSize:
      # We found the right buffer to insert.
      self.insert(data, location - prevSize, tempTail, isLastBuffer)
      return
    # The location is in the next buffer. We need to allocate a new buffer
    # which becomes the new tail of the queue.
    if location >= globalSize:
      let next = atomicLoadN(addr tempTail.next, AtomicAcquire)
      if next == nil:
        # No next buffer, allocate a new one.
        let newBuffer = createBuffer(tempTail)
        var nilPtr: ptr BufferList[T]
        # Try setting the successor of the current buffer to point to our new buffer.
        if atomicCompareExchangeN(addr tempTail.next, addr nilPtr, newBuffer,
            false, AtomicSeqCst, AtomicSeqCst):
          # Only one thread comes here and updates the next pointer.
          atomicStoreN(addr tempTail.next, newBuffer, AtomicRelease)
        else:
          # CAS was unsuccessful, we can drop our buffer.
          deallocShared(newBuffer)
      else:
        # If next is not null, we update the tail and proceed on the that buffer.
        discard atomicCompareExchangeN(addr self.tailOfQueue, addr tempTail, next,
            false, AtomicSeqCst, AtomicSeqCst)

proc foldBuffer[T](self: var MpscQueue[T], buffer: var ptr BufferList[T],
    bufferHead: var int): bool =
  let next = atomicLoadN(addr buffer.next, AtomicAcquire)
  let prev = buffer.prev
  if next == nil:
    # We reached the last buffer, which cannot be dropped.
    return false
  next.prev = prev
  atomicStoreN(addr prev.next, next, AtomicRelease)
  # Drop current buffer
  deallocShared(buffer)
  # Advance to the next buffer.
  buffer = next
  bufferHead = buffer.head
  result = true

# The element at the head of the queue (which is not set yet).
proc scan[T](self: var MpscQueue[T], node: ptr Node[T],
    tempHeadOfQueue: var ptr BufferList[T], tempHead: var int, tempNode: var ptr Node[T]) =
  var scanHeadOfQueue = self.headOfQueue
  var scanHead = scanHeadOfQueue.head
  while node[].state == Empty and scanHeadOfQueue != tempHeadOfQueue or
      scanHead < tempHead - 1:
    if scanHead > BufferSize:
      # We reached the end of the current buffer and switch to the next.
      scanHeadOfQueue = atomicLoadN(addr scanHeadOfQueue.next, AtomicAcquire)
      scanHead = scanHeadOfQueue.head
    else:
      # Move forward inside the current buffer.
      let scanNode = addr scanHeadOfQueue.nodes[scanHead]
      inc scanHead
      if scanNode[].state == Set:
        # We found a new candidate to dequeue and restart
        # the scan from the head of the queue to that element.
        tempHead = scanHead
        tempHeadOfQueue = scanHeadOfQueue
        tempNode = scanNode
        # re-scan from the beginning of the queue
        scanHeadOfQueue = self.headOfQueue
        scanHead = scanHeadOfQueue.head

proc search[T](self: var MpscQueue[T], head: int, node: ptr Node[T]; dst: var T): bool =
  var tempBuffer = self.headOfQueue
  var tempHead = head
  # Indicates if we need to continue the search in the next buffer.
  var searchNextBuffer = false
  # Indicates if all nodes in the current buffer are handled.
  var allHandled = true
  while node[].state == Empty:
    # There are unhandled elements in the current buffer.
    if tempHead < BufferSize:
      # Move forward inside the current buffer.
      var tempNode = addr self.headOfQueue.nodes[tempHead]
      inc tempHead
      # We found a set node which becomes the new candidate for dequeue.
      if tempNode[].state == Set and node[].state == Empty:
        # We scan from the head of the queue to the new candidate and
        # check if there has been any node set in the meantime.
        # If we find a node that is set, that node becomes the new
        # dequeue candidate and we restart the scan process from the head.
        # This process continues until there is no change found during scan.
        # After scanning, `temp_node` stores the candidate node to dequeue.
        self.scan(node, tempBuffer, tempHead, tempNode)
        # Check if the actual head has been set in between.
        if node[].state == Set:
          return false
        # Dequeue the found candidate.
        dst = tempNode[].data
        if searchNextBuffer and (tempHead - 1 == tempBuffer.head):
          # If we moved to a new buffer, we need to move the head forward so
          # in the end we can delete the buffer.
          inc tempBuffer.head
        return true
      if tempNode[].state == Empty:
        allHandled = false
    # We reached the end of the current buffer, move to the next.
    # This also performs a cleanup operation called `fold` that
    # removes buffers in which all elements are handled.
    if tempHead >= BufferSize:
      if allHandled and searchNextBuffer:
        # If all nodes in the current buffer are handled, we try to fold the
        # queue, i.e. remove the intermediate buffer.
        if self.foldBuffer(tempBuffer, tempHead):
          allHandled = true
          searchNextBuffer = true
        else:
          # We reached the last buffer in the queue.
          return false
      else:
        let next = atomicLoadN(addr tempBuffer.next, AtomicAcquire)
        if next == nil:
          # We reached the last buffer in the queue.
          return false
        tempBuffer = next
        tempHead = tempBuffer.head
        allHandled = true
        searchNextBuffer = true

proc dequeue*[T](self: var MpscQueue[T]; dst: var T): bool =
  while true:
    # The buffer from which we eventually dequeue from.
    let tempTail = atomicLoadN(addr self.tailOfQueue, AtomicSeqCst)
    # The number of items in the queue without the current buffer.
    let prevSize = sizeWithoutBuffer(tempTail)

    template head: untyped = self.headOfQueue.head
    let headIsTail = self.headOfQueue == tempTail
    let headIsEmpty = head == atomicLoadN(addr self.tail, AtomicAcquire) - prevSize

    # The queue is empty.
    if headIsTail and headIsEmpty:
      return false
    # There are un-handled elements in the current buffer.
    elif head < BufferSize:
      let node = addr self.headOfQueue.nodes[head]
      # Check if the node has already been dequeued.
      # If yes, we increment head and move on.
      if node[].state == Handled:
        inc head
      # The current head points to a node that is not yet set or handled.
      # This means an enqueue thread is still ongoing and we need to find
      # the next set element (and potentially dequeue that one).
      else:
        if node[].state == Empty:
          if self.search(head, node, dst):
            return true
        # The current head points to a valid node and can be dequeued.
        if node[].state == Set:
          # Increment head
          inc head
          dst = node[].data
          return true
    # The head buffer has been handled and can be removed.
    # The new head becomes the successor of the current head buffer.
    if head >= BufferSize:
      if self.headOfQueue == atomicLoadN(addr self.tailOfQueue, AtomicAcquire):
        # There is only one buffer.
        return false
      let next = atomicLoadN(addr self.headOfQueue.next, AtomicAcquire)
      if next == nil:
        return false
      # Drop head buffer.
      deallocShared(self.headOfQueue)
      self.headOfQueue = next
