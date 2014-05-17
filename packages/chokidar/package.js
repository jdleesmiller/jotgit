Package.describe({ summary: "Chokidar" });

Npm.depends({ "chokidar": "0.8.2" });

Package.on_use(function (api) {
  api.export('Chokidar');
  api.add_files('chokidar.js', 'server');
});
