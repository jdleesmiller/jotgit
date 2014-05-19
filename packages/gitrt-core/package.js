Package.describe({ summary: "gitrt-core" });

// note: there is a bug in ot 0.0.14 that's fixed in master, but meteor
// currently requires us to specify a particular commit here
Npm.depends({
  "chokidar": "0.8.2",
  "shelljs": "0.3.0",
  "ot": "https://github.com/Operational-Transformation/ot.js/tarball/3ab1be8efadd64141e3c13ca4e02325d0331882f"
});

Package.on_use(function (api) {
  api.use('coffeescript');
  api.export('GitRt');
  api.export('ot');

  api.add_files([
    'gitrt.coffee',
    'repo.coffee',
    'editor-server.coffee'], 'server');

  var otPath = '.npm/package/node_modules/ot/lib/';

  api.add_files([
    'client.js',
    otPath + 'text-operation.js',
    otPath + 'selection.js',
    otPath + 'wrapped-operation.js',
    otPath + 'undo-manager.js',
    otPath + 'client.js',
    otPath + 'codemirror-adapter.js',
    otPath + 'editor-client.js'], ['client'], {bare: true});
});

