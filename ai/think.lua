local Think = class()

Think.name = "thinking"
Think.does = "jelly:think"
Think.args = { thought = "string" }
Think.version = 2
Think.priority = 1

function Think:run(ai, entity, args)
  radiant.entities.think(entity, args.thought)
end

return Think