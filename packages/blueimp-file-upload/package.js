Package.describe({ summary: "blueimp jquery file upload" });

Npm.depends({ "blueimp-file-upload": "9.5.8" });

Package.on_use(function (api) {
  api.export('FileUpload');
  api.add_files('file-upload.js', 'client');
});
