Package.describe({ summary: "NodeGit" });

Npm.depends({ "nodegit": "0.1.3" });

Package.on_use(function (api) {
  api.export('NodeGit');
  api.add_files('nodegit.js', 'server');
});
