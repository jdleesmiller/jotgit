Meteor.startup ->

  Meteor.settings.projectPath ||= '/tmp/11'

  repo = new GitRt.Repo(Meteor.settings.projectPath)

  editorServers = {}

  Meteor.publish 'files', ->
    self = this

    handleAdded = (path) -> self.added('files', path, {path: path})
    repo.addListener 'added', handleAdded

    handleRemoved = (path) -> self.removed('files', path)
    repo.addListener 'removed', handleRemoved

    self.added('files', path, {path: path}) for path in repo.entries()

    self.onStop ->
      repo.removeListener 'added', handleAdded
      repo.removeListener 'removed', handleRemoved

    self.ready()

  Meteor.publish 'fileInfo', (filePath) ->
    self = this

    server = editorServers[filePath] ||= new GitRt.EditorServer(
      repo.readFile(filePath))

    self.added('fileInfo', filePath,
      clientId: this.connection.id,
      revision: server.revision(),
      document: server.document())

    self.ready()

  Meteor.publish 'fileOperations', (filePath, startRevision) ->
    self = this

    server = editorServers[filePath]
    throw new Error("no server for #{filePath}") unless server

    # TODO clean this up
    for operation, revision in server.operations().slice(startRevision)
      self.added 'fileOperations', revision + startRevision,
        clientId: null,
        operation: operation.wrapped.toJSON()

    handleOperationApplied = (clientId, operation, selection) ->
      console.log ['op applied', operation]
      self.added 'fileOperations', server.revision(),
        clientId: clientId,
        operation: operation.wrapped.toJSON(),
        selection: selection
    server.addListener 'operationApplied', handleOperationApplied

    self.onStop ->
      server.removeListener 'operationApplied', handleOperationApplied

    self.ready()

  Meteor.publish 'fileSelections', (filePath) ->
    self = this

    server = editorServers[filePath]
    throw new Error("no server for #{filePath}") unless server

    self.added 'fileSelections', filePath, {}

    handleSelectionsUpdated = (selections) ->
      console.log selections
      self.changed 'fileSelections', filePath, selections
    server.addListener 'selectionsUpdated', handleSelectionsUpdated

    self.onStop ->
      server.removeListener 'selectionsUpdated', handleSelectionsUpdated

    self.ready()

  Meteor.methods(
    sendOperation: (filePath, revision, operation, selection) ->
      try
        console.log ['sendOperation', arguments...]
        server = editorServers[filePath]
        throw new Error("no server for #{filePath}") unless server

        clientId = this.connection.id
        server.receiveOperation(clientId, revision, operation, selection)
        
        'ack'
      catch error
        console.log error
        console.log error.stack
        'fail' # TODO the client doesn't care

    sendSelection: (filePath, selection) ->
      server = editorServers[filePath]
      throw new Error("no server for #{filePath}") unless server

      clientId = this.connection.id
      server.updateSelection(clientId, selection)
  )

  #  openFile: (filePath) ->
  #    server = editorServers[filePath] ||= new GitRt.EditorServer(
  #      repo.readFile(filePath))

  #    {clientId: Math.random(), document: server.document()}
  #  edit: (clientId, filePath, revision, operation, selection) ->
  #    null

