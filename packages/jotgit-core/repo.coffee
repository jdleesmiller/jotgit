EventEmitter = Npm.require('events').EventEmitter
Path = Npm.require('path')
fs = Npm.require('fs')
Future = Npm.require('fibers/future')
spawn = Npm.require('child_process').spawn
shelljs = Npm.require('shelljs')
chokidar = Npm.require('chokidar')
zlib = Npm.require('zlib')

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

    # note: man git-init(1) says it is OK to run init more than once
    unless fs.existsSync(Path.join(@repoPath, '.git'))
      @runInRepoPath 'git', ['init']

    # this config option is required in order to accept a git push even though
    # we have a working copy checked out; this won't be necessary when we use
    # the bare repo instead
    @runInRepoPath 'git', ['config', 'receive.denyCurrentBranch', 'ignore']

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

  streamFile: (path, output) ->
    absolutePath = @checkPath(path)
    future = new Future()
    input = fs.createReadStream(absolutePath)
    input.on 'error', (err) -> future.throw(err)
    input.on 'close', () -> future.return()
    input.pipe(output)
    future.wait()

  gzipStreamFile: (path, output) ->
    future = new Future()
    gzip = zlib.createGzip()
    gzip.on 'error', (err) -> future.throw(err)
    gzip.on 'close', () -> future.return()
    gzip.pipe(output)
    @streamFile(path, gzip)
    future.wait()

  writeFile: (path, data) ->
    absolutePath = @checkPath(path)
    fs.writeFileSync(absolutePath, data, encoding: 'utf8')

  createFile: (path) ->
    absolutePath = @checkPath(path)
    fs.writeFileSync(absolutePath, '', encoding: 'utf8')

  spawnInRepoPath: (command, args=[], options={}) ->
    options.cwd = @repoPath
    spawn(command, args, options)

  waitOnSpawn: (child) ->
    future = new Future()
    child.on 'close', (code, signal) ->
      future.return(code: code, signal: signal)
    child.on 'error', (err) ->
      future.throw(err)
    future.wait()

  runInRepoPath: (command, args=[], options={}) ->
    options.stdio ||= ['ignore', 1, 2] # echo output to server logs
    child = @spawnInRepoPath(command, args, options)
    @waitOnSpawn(child)

  commit: (message) ->
    message ||= 'saved'
    addResult = @runInRepoPath('git', ['add', '.'])
    console.log addResult
    if addResult.code == 0
      commitResult = @runInRepoPath('git', ['commit', '--message', message])
      console.log commitResult
      if commitResult.code == 0
        'success'
      else if commitResult.code == 1
        'no changes'
      else
        'commit failed'
    else
      'add failed' # not sure what would cause this to fail

  setNoCacheHeaders: (response) ->
    response.setHeader 'Expires', 'Fri, 01 Jan 1980 00:00:00 GMT'
    response.setHeader 'Pragma', 'no-cache'
    response.setHeader 'Cache-Control', 'no-cache, max-age=0, must-revalidate'

  gitPacket: (packet) ->
    # prefix packet with 4-digit zero-padded length in hexadecimal
    length = "0000#{(packet.length + 4).toString(16)}".slice(-4)
    "#{length}#{packet}"

  getFromService: (response, service) ->
    @setNoCacheHeaders response
    response.setHeader 'Content-Type', "application/x-#{service}-advertisement"

    response.write @gitPacket("# service=#{service}\n") + "0000"

    child = @spawnInRepoPath(
      service, ['--stateless-rpc', '--advertise-refs', '.'],
      stdio: ['ignore', 'pipe', 2])
    child.stdout.pipe response
    @waitOnSpawn(child)

  postToService: (request, response, service) ->
    @setNoCacheHeaders response
    response.setHeader 'Content-Type', "application/x-#{service}-result"

    child = @spawnInRepoPath(
      service, ['--stateless-rpc', '.'],
      stdio: ['pipe', 'pipe', 2])
    request.pipe child.stdin
    child.stdout.pipe response
    @waitOnSpawn(child)

  resetHard: ->
    @runInRepoPath 'git', ['reset', '--hard']

Jotgit.Repo = Repo
