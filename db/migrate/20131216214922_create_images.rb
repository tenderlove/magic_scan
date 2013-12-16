class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.string  :type
      t.references :card
      t.integer :fingerprint_l
      t.integer :fingerprint_r
      t.string  :filename

      t.timestamps
    end
    add_index :images, :type
    add_index :images, :card_id
  end
end
