@Jotgit ||= {}

@Files = new Meteor.Collection('files')

@FileInfo = new Meteor.Collection('fileInfo')

@FileOperations = new Meteor.Collection('fileOperations')

@FileSelections = new Meteor.Collection('fileSelections')

Template.files.files = -> Files.find()

Template.files.events(
  'click a.createFile': ->
    $('a.createFile').text('choose new file name...')
    filename = prompt('Please enter a new file name:')
    if filename == null
      filename = 'unnamed.md'

    filename = verifyFileName(filename)

    Meteor.call 'createFile', filename, (error, result) ->
      $('a.createFile').text('Create new file')
      alert(result) if result != 'success'
    false
)

Template.fileEdit.fileInfo = -> FileInfo.findOne()

autoSaveTimer = null

Template.fileEdit.events(
  'click div.btn-group.btn-toggle': ->
    $('.btn-toggle').children('.btn').toggleClass "active"
                                      .toggleClass "btn-primary"
    if $('#timer-on-button').hasClass("active")
      $('#timer-settings').css('display': 'inline-block')
      timeInMillisecs = getTimerMillis()
      if timeInMillisecs
        autoSaveTimer = Meteor.setInterval(commit, timeInMillisecs)
      else
        setTimer(5)
        autoSaveTimer = Meteor.setInterval(commit, 300000)
    else
      $('#timer-settings').hide()
      Meteor.clearInterval autoSaveTimer
    false
)

Template.fileEdit.events(
  'change #autosave-time': ->
    timeInMillisecs = getTimerMillis()
    if timeInMillisecs
      Meteor.clearInterval autoSaveTimer
      autoSaveTimer = Meteor.setInterval(commit, timeInMillisecs)
    else
      console.log 'invalid timer input'
    false
)

Template.fileEdit.events(
  'click a.commit': ->
    $('a.commit').text('saving...')
    message = prompt('Name for this save (optional):')
    if message == null
      $('a.commit').text('save project')
    else
      commit message
    false
)

Template.fileEdit.events(
  'click #file-name': ->
    $("#file-name").hide()
    $("#rename-form").css('display': 'inline-block')
    false
)

Template.fileEdit.events(
  'submit #rename-form': ->
    filename = verifyFileName($("#new-file-name").val())
    if filename == ".md"
      alert('enter a valid name')
    else
      Meteor.call 'renameFile', fileInfo._id, filename, (error, result) ->
        alert(result) if result != 'success'
      $("#rename-form").hide()
      $("#file-name").css('display': 'inline-block')
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

commit = (message = 'Autosave') ->
  console.log 'committing...'
  $('a.commit').text('saving...')
  Meteor.call 'commit', message, (error, result) ->
        $('a.commit').text('save project')
        alert(result) if result != 'success'

getTimerMillis =->
  timeInMinutes = parseFloat($('#autosave-time').val())
  if timeInMinutes.isNan
    return false
  else
    return timeInMinutes * 60000

setTimer = (time) ->
  $('#autosave-time').val(time)

verifyFileName = (filename) ->
  sublist = filename.split('.')
  if sublist.length == 1 || sublist[sublist.length-1] != 'md'
    filename += '.md'

  #precondition: filename ends on '.md'
  while Files.findOne({path: filename})
    filename = filename.substring(0, filename.length-3) + '-1.md'
  #postcondition: filename is unique
  return filename


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

