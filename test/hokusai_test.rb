require 'test_helper'
require "sqlite3"
require "active_record"
require "logger"
require 'pry'
require "pp"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :devices, force: true do |t|
    t.string :name
    t.string :model
    t.string :location
    t.integer :year
  end

  create_table :interfaces, force: true do |t|
    t.integer :device_id
    t.string :name
    t.string :address
    t.boolean :enabled
  end

  create_table :configs, force: true do |t|
    t.integer :device_id
    t.text :configuration
  end

  create_table :templates, force: true do |t|
    t.string :name
    t.string :hokusai_class
    t.text :hokusai_template
  end
end


class Device < ActiveRecord::Base
  include Hokusai::Templatable
  has_many :interfaces
  has_one :config
  template :name, :model, :location, :year, include: [:interfaces, :config]
end
class Interface < ActiveRecord::Base
  include Hokusai::Templatable
  belongs_to :device
  template :name, :address, :enabled
end
class Config < ActiveRecord::Base
  include Hokusai::Templatable
  belongs_to :device
  template :configuration
end
class Template < ActiveRecord::Base
  include Hokusai::Container
  validates :name, presence: true
  before_validation :ensure_name
  private
  def ensure_name
    self.name ||= "New #{hokusai_class.constantize.model_name.singular} template"
  end
end


class HokusaiTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Hokusai::VERSION
  end

  def test_basic_function
    device = Device.create!(name: "router", model: "CX-6790", location: "SFO", year: 2017)
    device.create_config(configuration: "# Device configuration file\ninterface de0;\ninterface lo0;\n")
    device.interfaces << Interface.create!([{name: "de0", address: "10.0.0.1", enabled: false}, {name: "lo0", address: "127.0.0.1", enabled: true}])

    Template.create!(origin: device, name: 'SFO router template')

    new_device = Template.last.stamp do |dev|
      dev.name = "router-2"
    end

    new_device.save!

    assert_equal 1, Template.count
    assert_equal 2, Device.count
    assert_equal 4, Interface.count
    assert_equal 2, new_device.interfaces.count
    assert_equal new_device.id, Interface.last.device.id

    pp new_device.as_json(include: :interfaces)
  end
end
