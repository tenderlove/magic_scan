class JoinTable < ActiveRecord::Migration
  def change
    create_table :cards_images, :id => false do |t|
      t.references :card
      t.references :image
    end
    add_index :cards_images, [:card_id, :image_id]
    add_index :cards_images, :card_id
    add_index :cards_images, :image_id
  end
end
