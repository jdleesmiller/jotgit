# gitrt

Git-backed real time collaborative editor built with meteor.

The current version of gitrt is a prototype that lets you collaboratively edit Markdown files in a git repository on the server where it runs. Then you can save the files (with an optional commit message), and they'll be committed to the repository.

## Getting Started

If you have not yet installed Meteor, do that:
```
curl https://install.meteor.com | /bin/sh
```
(This assumes that you're on unix.)

Clone this repository:
```
git clone https://github.com/jdleesmiller/gitrt.git
```

Start up meteor:
```
meteor
```
It should pull in all of the required dependencies. Make some tea.

Then visit [localhost:3000](http://localhost:3000) in your browser. Be sure to try with multiple windows!

By default, it loads up the test repository in `tests/demo`. To point it at another repository, you can either edit `server/gitrt.coffee` or use [http://docs.meteor.com/#meteor_settings](meteor settings) to specify an alternative `projectPath`.

## About

Gitrt ...

* is written in [http://coffeescript.org/](CoffeeScript), a language that looks a bit like Python and compiles to JavaScript.

* is built with [https://www.meteor.com/](Meteor), which is an up-and-comping web framework for real time web apps. It is remarkably developer-friendly, and it already has [http://docs.meteor.com/](very good documentation).

* is powered by [http://en.wikipedia.org/wiki/Operational_transformation](operational transformation), and in particular the excellent [https://github.com/operational-transformation/ot.js](ot.js) implementation.

* uses [http://codemirror.net/](CodeMirror) for the editing component.

The code is structured in the usual way for a meteor app: the files in `server` run on the server, the files in `client` run on the client, and the files in `lib` run on both. There's also a `gitrt-core` package in `packages/gitrt-core` that contains most of the core classes (stuff that is not very meteor-specific).

## Roadmap

* allow remote pushes to the repository

* multiple projects

* user accounts

* option to commit to github instead of a local git repo

* file type handling (various text files, binary files)

* file uploads

## License

MIT --- see LICENSE file.

