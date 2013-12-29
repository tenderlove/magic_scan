require 'reference_image'
require 'user_image'

class Card < ActiveRecord::Base
  has_and_belongs_to_many :images
end
