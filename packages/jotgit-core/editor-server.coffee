EventEmitter = Npm.require('events').EventEmitter
ot = Npm.require('ot')

# ot doesn't export this by default
ot.WrappedOperation = Npm.require(
  './npm/jotgit-core/main/node_modules/ot/lib/wrapped-operation.js')

#
# Wrapper around ot.js's ot.Server that handles serialisation and emits events
# that we consume in the publish functions that send transformed operations to
# all of the clients.
#
class EditorServer extends EventEmitter
  constructor: (document, operations=[]) ->
    @server = new ot.Server(document, operations)
    @clientSelections = {}

  document: -> @server.document
  operations: -> @server.operations
  revision: -> @server.operations.length

  # this is used to 'catch up' when a client first connects, because there may
  # be a delay between when the client receives the latest version upon
  # connecting and when it starts listening for further edits
  emitOperationsAfter: (startRevision) ->
    clientId = null
    selection = null
    for operation, revision in @operations().slice(startRevision)
      this.emit 'operationApplied', clientId, revision + startRevision,
        operation.wrapped.toJSON(), selection

  receiveOperation: (clientId, revision, operation, selection) ->
    wrapped = new ot.WrappedOperation(
      ot.TextOperation.fromJSON(operation),
      selection && ot.Selection.fromJSON(selection)
    )

    wrappedPrime = @server.receiveOperation(revision, wrapped)
    selectionPrime = wrappedPrime.meta
    @updateSelection(clientId, selectionPrime)

    this.emit 'operationApplied',
      clientId, @revision(), wrappedPrime.wrapped.toJSON(), selectionPrime

    null

  updateSelection: (clientId, selection) ->
    if selection
      @clientSelections[clientId] = ot.Selection.fromJSON(selection)
    else
      delete @clientSelections[clientId]

    this.emit 'selectionsUpdated', @clientSelections

    null
  
Jotgit.EditorServer = EditorServer
