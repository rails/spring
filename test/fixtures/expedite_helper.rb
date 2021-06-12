# Registrations used in ApplicationManagerTest
Expedite::Variants.register("parent")
Expedite::Variants.register("test", parent: "parent", keep_alive: true) do
end
