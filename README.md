# Setup Notes

on node 0.10.28 with meteor 0.8.1.2

nvm use 0.10
npm install -g meteorite

It looks like nodegit is built with an absolute path to the libgit2 dylib, but
meteor moves things around in the course of the build process and apparently
breaks it.

Workaround is to add a console.log(e) to
`packages/nodegit/.build/npm/node_modules/nodegit/index.js`
like this:
```
var rawApi;
try {
  rawApi = require('./build/Release/nodegit');
} catch (e) {
  console.log(e);
  rawApi = require('./build/Debug/nodegit');
}
```

Error looks like:

```
I20140517-17:50:55.827(1)? [Error: dlopen(/Users/john/ex/gitrt/packages/nodegit/.build/npm/node_modules/nodegit/build/Release/nodegit.node, 1): Library not loaded: /Users/john/ex/gitrt/packages/nodegit/.npm/package-new-1s6evra/node_modules/nodegit/vendor/libgit2/build/libgit2.0.dylib
I20140517-17:50:55.895(1)?   Referenced from: /Users/john/ex/gitrt/packages/nodegit/.build/npm/node_modules/nodegit/build/Release/nodegit.node
I20140517-17:50:55.895(1)?   Reason: image not found]
```

So created symlink:
```
mkdir -p packages/nodegit/.npm/package-new-1s6evra/node_modules/nodegit/vendor/libgit2/build/
ln -s $PWD/packages/nodegit/.build/npm/node_modules/nodegit/vendor/libgit2/build/libgit2.0.dylib packages/nodegit/.npm/package-new-1s6evra/node_modules/nodegit/vendor/libgit2/build/libgit2.0.dylib
```
