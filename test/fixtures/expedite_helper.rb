# Registrations used in ApplicationManagerTest
Expedite::Agents.register("parent")
Expedite::Agents.register("test", parent: "parent", keep_alive: true) do
end
