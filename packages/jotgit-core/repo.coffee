EventEmitter = Npm.require('events').EventEmitter
Path = Npm.require('path')
fs = Npm.require('fs')
Future = Npm.require('fibers/future')
spawn = Npm.require('child_process').spawn
shelljs = Npm.require('shelljs')
chokidar = Npm.require('chokidar')

syncExec = Meteor._wrapAsync(shelljs.exec)

#
# Very simple interface to a git repository.
#
# We use the working copy to
#
# 1) list the files in the project
#
# 2) read file content when initialising the server
#
# 3) write file content before committing it
#
# This approach lets us use the standard git commands to commit.
#
# We also watch for files to be added or removed from the working copy (that's
# what "chokidar" does). This isn't really used yet, but I think it may be when
# we get to accepting git pushes. For now, it's just fun to add a file and watch
# it show up in the web interface.
#
class Repo extends EventEmitter
  constructor: (@repoPath) ->
    self = this

    unless fs.existsSync(Path.join(@repoPath, '.git'))
      @spawnInRepoPath 'git', ['init']

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

  writeFile: (path, data) ->
    absolutePath = @checkPath(path)
    fs.writeFileSync(absolutePath, data, encoding: 'utf8')

  spawnInRepoPath: (command, args=[], options={}) ->
    options['cwd'] = @repoPath
    options['stdio'] ||= ['ignore', 1, 2] # echo output to server logs
    future = new Future()
    child = spawn(command, args, options)
    child.on 'close', (code, signal) ->
      future.return(code: code, signal: signal)
    child.on 'error', (err) ->
      future.throw(err)
    future.wait()

  commit: (message) ->
    message ||= 'saved'
    addResult = @spawnInRepoPath('git', ['add', '.'])
    console.log addResult
    if addResult.code == 0
      commitResult = @spawnInRepoPath('git', ['commit', '--message', message])
      console.log commitResult
      if commitResult.code == 0
        'success'
      else if commitResult.code == 1
        'no changes'
      else
        'commit failed'
    else
      'add failed' # not sure what would cause this to fail

Jotgit.Repo = Repo
