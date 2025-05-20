alias Data.Repo
alias Data.Character
alias Data.Item
alias Data.ItemStats

# Clear existing data to avoid duplication (optional)
# Repo.delete_all(ItemStats)
# Repo.delete_all(Item)
# Repo.delete_all(Character)

# Create Characters
IO.puts("Seeding characters...")

character1 = Repo.insert!(%Character{user_id: 1})
character2 = Repo.insert!(%Character{user_id: 2})

# Create Items
IO.puts("Seeding items...")

item1 =
  Repo.insert!(%Item{
    name: "Iron Sword",
    type: :sword,
    position: :right_hand,
    character_id: character1.id,
    sprite: "/images/sprite_5_1.png",
    equipped?: true
  })

item2 =
  Repo.insert!(%Item{
    name: "Wooden Bow",
    type: :bow,
    position: :two_hands,
    character_id: character2.id
  })

item3 =
  Repo.insert!(%Item{
    name: "Magic Staff",
    type: :staff,
    position: :two_hands,
    character_id: character1.id,
    equipped?: false
  })

# Create Item Stats
IO.puts("Seeding item stats...")

Repo.insert!(%ItemStats{
  item_id: item1.id,
  health: 10,
  physical_att: 15,
  magical_att: 0,
  physical_def: 5,
  magical_def: 2
})

Repo.insert!(%ItemStats{
  item_id: item2.id,
  health: 5,
  physical_att: 12,
  magical_att: 0,
  physical_def: 3,
  magical_def: 1
})

Repo.insert!(%ItemStats{
  item_id: item3.id,
  health: 8,
  physical_att: 0,
  magical_att: 20,
  physical_def: 4,
  magical_def: 10
})

IO.puts("Seeding complete!")
