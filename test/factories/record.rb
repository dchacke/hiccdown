require 'active_model'

class Record
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :foo

  def initialize(attributes = {})
    super

    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end
end
