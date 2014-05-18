EventEmitter = Npm.require('events').EventEmitter
Path = Npm.require('path')
fs = Npm.require('fs')
shelljs = Npm.require('shelljs')
chokidar = Npm.require('chokidar')

syncExec = Meteor._wrapAsync(shelljs.exec)

#
# Repository with file system event notification so we can publish changes.
#
# Mainly this is concerned with maintaining the file list. We want to use a
# simple meteor collection, so it has to be a linear view rather than a tree.
#
class Repo extends EventEmitter
  constructor: (@repoPath) ->
    self = this

    watcher = chokidar.watch(@repoPath,
      ignored: /\/\.git/,
      ignoreInitial: true)

    watcher.on 'add',
      (path) -> self.emit('added', self.relativePath(path))

    watcher.on 'unlink',
      (path) -> self.emit('removed', self.relativePath(path))

    watcher.on 'error', (error) -> console.log(error)

  entries: ->
    self = this
    paths = syncExec(
      "find #{@repoPath} -not -iwholename '*/.git*'", silent: true)
    paths.trim().split("\n").splice(1).map((path) -> self.relativePath(path))

  # beware directory traversal attacks
  checkPath: (path) ->
    resolvedPath = Path.join(@repoPath, path)
    if resolvedPath.indexOf(@repoPath) != 0
      throw new Error("path #{path} outside of repo")
    resolvedPath

  relativePath: (path) ->
    @checkPath(path)
    Path.relative(@repoPath, path)

  readFile: (path) ->
    absolutePath = @checkPath(path)
    fs.readFileSync(absolutePath, encoding: 'utf8')

GitRt.Repo = Repo
