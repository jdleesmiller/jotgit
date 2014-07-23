# jotgit

Git-backed real time collaborative editor built with meteor.

Here's a quick demo: [http://youtu.be/z-_wSiGS18U](http://youtu.be/z-_wSiGS18U)

The current version of jotgit is a prototype that lets you collaboratively edit Markdown files in a local git repository. Then you can save the files (with an optional commit message), and they'll be committed to the repository.

## Getting Started

This assumes that you're on Linux or Mac OS X.

First, you'll need to install node.js and meteorite, the package manager for meteor. The recommended way to do this is to first install the node version manager, following [these directions](https://github.com/creationix/nvm). The command will be something like:

```
curl https://raw.githubusercontent.com/creationix/nvm/v0.11.2/install.sh | bash
```

Then, restart your terminal, and run
```
nvm install 0.10
```
to install node 0.10 (the latest stable release, at the time of writing).

Install meteorite globally (via the node package manager, npm) with
```
npm install -g meteorite
```

If you have not yet installed Meteor, do that:
```
curl https://install.meteor.com | /bin/sh
```

Clone this repository:
```
git clone https://github.com/jdleesmiller/jotgit.git
```

Start up meteor with meteorite:
```
cd jotgit # or wherever you cloned it
mrt
```
It should pull in all of the required dependencies. Make some tea.

Then visit [localhost:3000](http://localhost:3000) in your browser. Be sure to try with multiple windows!

By default, it loads up the test repository in `tests/demo`. To point it at another repository, you can either edit `server/jotgit.coffee` or use [meteor settings](http://docs.meteor.com/#meteor_settings) to specify an alternative `projectPath`.

## About

Jotgit ...

* is written in [CoffeeScript](http://coffeescript.org/), a language that feels a bit like Python and compiles to JavaScript.

* is built with [Meteor](https://www.meteor.com/), which is an up-and-comping web framework for real time web apps. It is remarkably developer-friendly, and it already has [very good documentation](http://docs.meteor.com/).

* is powered by [operational transformation](http://en.wikipedia.org/wiki/Operational_transformation), and in particular the excellent [ot.js](https://github.com/operational-transformation/ot.js) implementation.

* uses [CodeMirror](http://codemirror.net/) for the editing component.

The code is structured in the usual way for a meteor app: the files in `server` run on the server, the files in `client` run on the client, and the files in `lib` run on both. There's also a `jotgit-core` package in `packages/jotgit-core` that contains most of the core classes (stuff that is not very meteor-specific).

## Roadmap

* allow remote pushes to the repository (mostly done, but still need to notify web clients after a push)

* auto-saves

* multiple projects

* user accounts

* some way of handling multiple commit authors (apparently not supported by git)

* option to commit to github instead of a local git repo

* file type handling (various text files, binary files)

* file uploads

## License

MIT --- see LICENSE file.

