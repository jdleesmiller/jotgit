Meteor.startup ->
  Meteor.settings.projectRoot ||= '/tmp'

  watcher = Chokidar.watch(Meteor.settings.projectRoot, ignored: /\/\.git/)
  watcher.on('add', (path) -> console.log(path))
  watcher.on('error', (error) -> console.log(error))

#Meteor.publish 'projectFiles', (projectId) ->
