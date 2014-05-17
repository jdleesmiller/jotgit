Template.projectsIndex.projects = ->
  Projects.find({})

Template.projectsIndex.events(
  'click #new-project': ->
    Projects.insert({})
)
