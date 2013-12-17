class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.string  :type, :null => false
      t.integer :fingerprint_l, :null => false
      t.integer :fingerprint_r, :null => false
      t.string  :filename, :null => false

      t.timestamps
    end
    add_index :images, :type
    add_index :images, [:fingerprint_l, :fingerprint_r]
  end
end
