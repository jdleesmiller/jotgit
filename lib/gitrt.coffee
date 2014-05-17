@Projects = new Meteor.Collection('projects')

@Files = new Meteor.Collection('files')

Router.map ->
  this.route 'home', path: '/'

  this.route 'projectsIndex',
    path: '/projects'
  this.route 'projectsShow',
    path: '/projects/:_id',
    data: -> Projects.findOne(this.params._id)

