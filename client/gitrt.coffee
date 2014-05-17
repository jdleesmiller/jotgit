Template.projectsIndex.projects = ->
  Projects.find({})

Template.projectsIndex.events(
  'click #new-project': ->
    Projects.insert(name: 'todo')
    alert(Projects.find().count())
)
