@GitRt ||= {}

@Files = new Meteor.Collection('files')

@FileInfo = new Meteor.Collection('fileInfo')

@FileOperations = new Meteor.Collection('fileOperations')

@FileSelections = new Meteor.Collection('fileSelections')

Template.files.files = -> Files.find()

Template.fileEdit.fileInfo = -> FileInfo.findOne()

# note: this isn't called when switching between files
Template.fileEdit.rendered = ->
  console.log 'rendered'
  GitRt.cm = CodeMirror.fromTextArea(editor,
    lineNumbers: true
  )
  GitRt.cmAdapter = new ot.CodeMirrorAdapter(GitRt.cm)

# note: this isn't called when switching between files
Template.fileEdit.destroyed = ->
  console.log 'destroyed'
  if GitRt.cm
    $(GitRt.cm.getWrapperElement()).remove()
    delete GitRt.cm

class MeteorServerAdapter
  constructor: (@filePath) ->

  sendOperation: (revision, operation, selection) ->
    self = this

    console.log ['send op', arguments...]
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
  console.log ['autorun fileInfo', fileInfo]
  if fileInfo
    # TODO is GitRt.cm guaranteed to be set here? looks like no
    try
      GitRt.cmAdapter.ignoreNextChange = true
      GitRt.cm.setValue fileInfo.document
    finally
      GitRt.cmAdapter.ignoreNextChange = false
    GitRt.cm.focus()
    # TODO are we going to handle clients ourselves?
    clients = []
    console.log fileInfo
    serverAdapter = new MeteorServerAdapter(fileInfo._id)
    GitRt.editorClient = new ot.EditorClient(fileInfo.revision, clients,
      serverAdapter, GitRt.cmAdapter)

    Meteor.subscribe('fileOperations', fileInfo._id)
    Meteor.subscribe('fileSelections', fileInfo._id)

    lastRevision = 0
    Deps.autorun ->
      operations = FileOperations.find(
        {_id: {$gt: lastRevision}}, sort: {_id: 1})
      operations.forEach (operation) ->
        console.log operation
        lastRevision = operation._id
        if operation.clientId != fileInfo.clientId
          serverAdapter.trigger('operation', operation.operation)
          serverAdapter.trigger('selection',
            operation.clientId, operation.selection)

    Deps.autorun ->
      selections = FileSelections.findOne()
      for clientId, selection of selections
        serverAdapter.trigger('selection', clientId, selection)

