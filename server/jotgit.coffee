path = Npm.require('path')
http = Npm.require('http')

Meteor.startup ->

  Meteor.settings.projectPath ||= path.join(process.env.PWD, 'tests/demo')

  repo = new Jotgit.Repo(Meteor.settings.projectPath)

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

    server = editorServers[filePath] ||= new Jotgit.EditorServer(
      repo.readFile(filePath))

    self.added 'fileInfo', filePath,
      clientId: this.connection.id
      revision: server.revision()
      document: server.document()

    self.ready()

  Meteor.publish 'fileOperations', (filePath, startRevision) ->
    self = this

    server = editorServers[filePath]
    throw new Error("no server for #{filePath}") unless server

    handleOperationApplied = (clientId, revision, operationJson, selection) ->
      console.log ['op applied', operationJson]
      self.added 'fileOperations', revision,
        clientId: clientId
        operation: operationJson
        selection: selection
    server.addListener 'operationApplied', handleOperationApplied

    server.emitOperationsAfter startRevision

    self.onStop ->
      server.removeListener 'operationApplied', handleOperationApplied

    self.ready()

  Meteor.publish 'fileSelections', (filePath) ->
    self = this
    
    # TODO we never remove clients at the moment, so their selections are
    # immortal; we should be handling client disconnections

    server = editorServers[filePath]
    throw new Error("no server for #{filePath}") unless server

    self.added 'fileSelections', filePath, {}

    handleSelectionsUpdated = (selections) ->
      self.changed 'fileSelections', filePath, selections
    server.addListener 'selectionsUpdated', handleSelectionsUpdated

    self.onStop ->
      server.removeListener 'selectionsUpdated', handleSelectionsUpdated

    self.ready()

  Meteor.methods(
    sendOperation: (filePath, revision, operation, selection) ->
      try
        server = editorServers[filePath]
        throw new Error("no server for #{filePath}") unless server

        clientId = this.connection.id
        server.receiveOperation(clientId, revision, operation, selection)
        
        'ack'
      catch error
        console.log error
        console.log error.stack
        'fail' # TODO the client doesn't trap this, but it could do

    sendSelection: (filePath, selection) ->
      server = editorServers[filePath]
      throw new Error("no server for #{filePath}") unless server

      clientId = this.connection.id
      server.updateSelection(clientId, selection)

    commit: (message) ->
      for filePath, server of editorServers
        repo.writeFile filePath, server.document()
      result = repo.commit(message)
      result

    createFile: (fileName) ->
      repo.createFile fileName
      'success'
  )

  checkMethod = (request, response, allowedMethod) ->
    if request.method == allowedMethod
      return true
    else
      response.statusCode = 405
      response.setHeader 'Allow', allowedMethod
      response.write "405 Method Not Allowed\n"
      return false

  #
  # git push and pull using the 'smart' protocol
  #
  # This is based on "Implementing a Git HTTP Server" by Michael F. Collins, III
  # http://www.michaelfcollins3.me/blog/2012/05/18/implementing-a-git-http-server.html
  #
  # Some other libraries that may be helpful here:
  # https://github.com/substack/pushover
  # https://github.com/schacon/grack
  #
  Router.map ->
    @route 'projectGitInfoRefs',
      path: '/project.git/info/refs'
      where: 'server'
      action: ->
        return unless checkMethod(@request, @response, 'GET')
        service = @request.query.service
        if service == 'git-receive-pack' || service == 'git-upload-pack'
          repo.getFromService(@response, service)
        else
          @response.statusCode = 500 # TODO do something else here?
          @response.write "500 Internal Server Error\n"

    @route 'projectGitReceivePack',
      path: '/project.git/git-receive-pack'
      where: 'server'
      action: ->
        return unless checkMethod(@request, @response, 'POST')
        repo.postToService(@request, @response, 'git-receive-pack')
        repo.resetHard()

    @route 'projectGitReceivePack',
      path: '/project.git/git-upload-pack'
      where: 'server'
      action: ->
        return unless checkMethod(@request, @response, 'POST')
        repo.postToService(@request, @response, 'git-upload-pack')
