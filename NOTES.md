# Setup Notes

## 2014-05-17

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

## 2014-06-15

### git auto-save

* should not allow push or pull while this is in progress -- auto save may cause a git GC, which could change pack files and confuse things (but maybe it would be OK; I don't really know), and push / pull may interfere with commit

* can in principle continue to accept OT ops, but if we truncate the server's op list, then any "in flight" operations against older revisions won't be transformable

    * in practice, we probably won't throw away the ops, but instead store them, possibly after composing them; if we compose them, then we have the same problem: unable to transform in flight ops

* pausing editing for auto-saves seems undesirable, so we probably shouldn't clear the op log on auto-save; the clearing can be a separate process that truncates at a fixed limit set to keep memory use under control

* we do need to be able to work out whether there are changes, but the safest way to do this is to update the work dir and check; we could instead remember the last revision number saved to git, but there may be ops that cancel each other out, so the auto save would have nothing to do anyway

### git pull

* must git auto-save first

* can allow edits to continue during the pull

### git push

* the main idea is to reject the push if the merge is non-trivial; this puts the burden of handling merge conflicts on the git user

* the strictest way to define a "non-trivial" merge is to reject any push that isn't a fast forward; this conceptually simple, but the user experience isn't great
    * there's a receive.denyNonFastForwards config option that tells git-receive-pack not to allow forced pushes, so we can set that; on the other hand, we could allow forced pushes if that's what people decide they want, provided we can bound the damage that it can do to the editor
    * the timings would be:
        * we can tell when a client is initiating a push by looking for a request to info/refs with a service=receive-pack parameter
        * lock the web interface for the whole project, because we don't know which files will be updated, and we don't want to lose edits
        * do an auto-save to ensure that the latest content is committed, so HEAD is up to date
        * handle the push in the usual way
        * wait for the push to finish
        * then we can unlock the web interface for the project
    * for the git user, this could be annoying, because if I try to push while someone is actively typing, my push will get rejected, and then I have to go through a whole git pull --rebase cycle before I can try again; by this time, there may well be more minor edits, so I'd get rejected again, etc.;  on the other hand, documents tend to be edited sporadically, so conficts are not all that likely, so this might not be as bad as it sounds
    * for the web user, it's annoying to lock the whole project, because there might not actually be any conflict
        * we could suspend edits (i.e. server receives them but holds the acknowledgements) and allow web users to keep editing and then, if it turned out that there weren't any changes to their file, just apply the edits as normal; if there were changes, we'd have to throw them out, however, which would be even more annoying; if pushes are short, then this wouldn't be too bad, but I've seen some fairly long git pushes with github and heroku (minutes), esp. when uploading large binaries.

* the right way to do it (TM) is to treat the diffs from the git push as OT ops; this would look something like:
    * when client pushes, decide whether the latest save is "recent enough", by some measure
    * if it is, continue with the last save; othewrise, do an auto-save and use that instead
    * now check whether the push is a fast forward with respect to the latest save; if it is, accept it; otherwise, abort
    * once the push is finished, find diffs between the pushed version and the last save; convert them to OT ops (could use line-wise diffs or try to get character-wise diffs) and transform them against the relevant OT ops in the server's operation queue
    * this solves both problems
