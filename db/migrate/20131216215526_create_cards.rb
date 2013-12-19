class CreateCards < ActiveRecord::Migration
  def change
    create_table :cards do |t|
      t.string  :name
      t.integer :mv_id
      t.string  :mana_cost
      t.integer :converted_mana_cost
      t.string  :types
      t.text    :text
      t.string  :pt
      t.string  :rarity
      t.float   :rating

      t.timestamps
    end
    add_index :cards, :mv_id
  end
end
