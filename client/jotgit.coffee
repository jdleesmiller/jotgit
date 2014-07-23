@Jotgit ||= {}

@Files = new Meteor.Collection('files')

@FileInfo = new Meteor.Collection('fileInfo')

@FileOperations = new Meteor.Collection('fileOperations')

@FileSelections = new Meteor.Collection('fileSelections')

Template.files.files = -> Files.find()

Template.fileEdit.fileInfo = -> FileInfo.findOne()

Template.fileEdit.events(
  'click a.commit': ->
    $('a.commit').text('saving...')
    message = prompt('Name for this save (optional):')
    if message == null
      $('a.commit').text('save project')
    else
      Meteor.call 'commit', message, (error, result) ->
        $('a.commit').text('save project')
        alert(result) if result != 'success'
    false
)

Template.fileEdit.events(
  'click a.createFile': ->
    $('a.createFile').text('choose new file name...')
    message = prompt('Please enter a new file name:')
    if message == null
      message = 'unnamed.md'
    # missing: * check if file exists already
    #          * add '.md' if necessary
    Meteor.call 'createFile', message, (error, result) ->
      $('a.createFile').text('Create new file')
      alert(result) if result != 'success'
    false
)

# note: this isn't called when switching between files
Template.fileEdit.rendered = ->
  Jotgit.cm = CodeMirror.fromTextArea(editor,
    lineNumbers: true
  )
  Jotgit.cmAdapter = new ot.CodeMirrorAdapter(Jotgit.cm)

# note: this isn't called when switching between files
Template.fileEdit.destroyed = ->
  if Jotgit.cm
    $(Jotgit.cm.getWrapperElement()).remove()
    delete Jotgit.cm

class MeteorServerAdapter
  constructor: (@filePath) ->

  sendOperation: (revision, operation, selection) ->
    self = this

    Meteor.call('sendOperation', @filePath, revision, operation,
      selection, -> self.trigger('ack'))

  sendSelection: (selection) ->
    Meteor.call('sendSelection', @filePath, selection)

  registerCallbacks: (cb) -> @callbacks = cb

  trigger: (event) ->
    action = this.callbacks && this.callbacks[event]
    action.apply(this, Array.prototype.slice.call(arguments, 1)) if action

Deps.autorun ->
  fileInfo = FileInfo.findOne()
  if fileInfo
    # TODO is Jotgit.cm guaranteed to be set here? looks like no
    try
      Jotgit.cmAdapter.ignoreNextChange = true
      Jotgit.cm.setValue fileInfo.document
    finally
      Jotgit.cmAdapter.ignoreNextChange = false
    Jotgit.cm.focus()
    # TODO are we going to handle clients ourselves?
    clients = []
    serverAdapter = new MeteorServerAdapter(fileInfo._id)
    Jotgit.editorClient = new ot.EditorClient(fileInfo.revision, clients,
      serverAdapter, Jotgit.cmAdapter)

    Meteor.subscribe('fileOperations', fileInfo._id)
    Meteor.subscribe('fileSelections', fileInfo._id)

    lastRevision = 0
    Deps.autorun ->
      operations = FileOperations.find(
        {_id: {$gt: lastRevision}}, sort: {_id: 1})
      operations.forEach (operation) ->
        lastRevision = operation._id
        if operation.clientId != fileInfo.clientId
          serverAdapter.trigger('operation', operation.operation)
          serverAdapter.trigger('selection',
            operation.clientId, operation.selection)

    Deps.autorun ->
      selections = FileSelections.findOne()
      for clientId, selection of selections
        serverAdapter.trigger('selection', clientId, selection)

