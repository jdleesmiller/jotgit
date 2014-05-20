Router.map ->
  this.route 'home',
    path: '/'
    waitOn: -> Meteor.subscribe('files')

  this.route 'fileEdit',
    path: '/files/:path'
    waitOn: ->
      [Meteor.subscribe('files'),
       Meteor.subscribe('fileInfo', this.params.path)]
