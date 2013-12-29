class AddReviewToImages < ActiveRecord::Migration
  def change
    add_column :images, :needs_review, :boolean, :default => false
  end
end
