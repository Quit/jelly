local Unthink = class()

Unthink.name = "unthinking"
Unthink.does = "jelly:unthink"
Unthink.args = { thought = "string" }
Unthink.version = 2
Unthink.priority = 1

function Unthink:run(ai, entity, args)
  radiant.entities.unthink(entity, args.thought)
end

return Unthink