# Hokusai

Stamp out domain-specific clones of a model object, even after the original has departed, with these lightweight ActiveRecord concerns.

## Quick demo

If you want to write code like this, snapshotting an ActiveRecord object (and perhaps some associations) into a template:

```ruby
@template = Template.create!(origin: @project, name: "New template from project")
```

hoping to use it like this, at some later time (perhaps long after the origin has been deleted):

```
template = Template.find(params[:template_id])
@new_project = template.stamp do |project|
  project.name = "New project from template"
end
```

then you have (maybe) come to the right place.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hokusai'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hokusai

## Usage

Include `Hokusai::Container` in an ActiveRecord model so that we can save templates in it. The columns `hokusai_class` and `hokusai_template` are required. You can add whatever data or metadata you wish, from a simple name to complex lifecycle or ownership attributes. In this example we just require a name:

```ruby
class Template < ApplicationRecord
  include Hokusai::Container
  validates :name, presence: true
  before_validation :ensure_name

  private
  def ensure_name
    self.name = "New #{hokusai_class.constantize.model_name.singular} template"
  end
end
```

Now create and run a suitable migration:

```ruby
class CreateTemplates < ActiveRecord::Migration
  def change
    create_table :templates do |t|
      t.string :name, null: false
      t.string :hokusai_class, null: false
      t.text :hokusai_template, null: false
      t.timestamps
    end
  end
end
```

Then include `Hokusai::Templatable` in the models you want to make templates from. Declare a list of columns to persist, and which associations to include:

```ruby
class Device < ApplicationRecord
  include Hokusai::Templatable

  template :name, :model, :location, :year, include: [:interfaces]
  has_many :interfaces
end

class Interface < ApplicationRecord
  include Hokusai::Templatable
  belongs_to :device

  template :name, :address, :enabled
end
```

You can then create a new template, and stamp out a copy:

```ruby
device = Device.create!(name: "router-1", model: "CX-6790", location: "SFO", year: 2017)
device.interfaces.create!([
  {name: "de0", address: "10.0.0.1", enabled: false},
  {name: "lo0", address: "127.0.0.1", enabled: true}
])

template = Template.create!(origin: device, name: 'SFO router template')

new_device = template.stamp do |device|
  device.name = "router-2"
end

new_device.save!
```

This example ends with a deep, domain-specific clone of the origin object. You can delete the origin and the template is still useful.

### What can Hokusai stamp out?

Broadly speaking, this is intended for any ActiveRecord object that can be serialized to & from YAML.

The `Hokusai::Templatable` concern is provided. This handles ordinary `has_many`, `has_one`, and `belongs_to` associations via the `include:` option, in which case it will call `as_template` on the associated records.  If you want a `belongs_to` reference id to carry across, serialize the _id column rather than including the association in the template.

Recursive serialization is not currently detected and will cause a "stack level too deep" error. For those you may need to implement `as_template` by hand.

Aggregates types may also need special treatment.  You can override `read_attribute_for_template` in the model for these.

### Advanced configuration

You're not constrained to using `Hokusai::Templatable`.  Any model that implements `#as_template` and `::from_template` will do, and the container doesn't impose constraints on what they do.  The only expectation is that `#as_template` returns a data structure ready for serialization as YAML, and that `::from_template` accepts the same structure as the first parameter.  Beyond that you can do as you please with the data.

## Todo

* Generator for the container migration.
* Support for serializing self-referential data structures.
* Clearer tests.
* Comprehensive tests for a wide range of complicated associations.
* Remove dependency on ActiveRecord.
* Support configurable column names and template assignment method name.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/inopinatus/hokusai.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

