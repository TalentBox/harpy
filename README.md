Harpy
======

[![Build Status](https://travis-ci.org/TalentBox/harpy.png?branch=master)](https://travis-ci.org/TalentBox/harpy)
[![Code Climate](https://codeclimate.com/github/TalentBox/harpy.png)](https://codeclimate.com/github/TalentBox/harpy)

Client for REST API with HATEOAS

Dependencies
------------

* Ruby 1.8.7 or 1.9.2
* gem "typhoeus", "~> 0.2.4"
* gem "activesupport", ">= 3.1.0"
* gem "activemodel", ">= 3.1.0"
* gem "hash-deep-merge", "~> 0.1.1"

Usage
-----

* Set entry_point url:

        Harpy.entry_point_url = "http://localhost"

* Include `Harpy::Resource` in your model:

        class MyModel
          include Harpy::Resource
        end

        # Mass assignment
        model = MyModel.new "firstname" => "Anthony", "lastname" => "Stark"
        model.attributes = {"company" => "Stark Enterprises"}
        model.firstname # => "Anthony"
        model.company # => "Stark Enterprises"

        # Because model is not persisted you can read any attribute, allowing
        # to use form_for on new resources to which the client doesn't know the
        # existing attributes yet
        model.email # => nil

        # Fetch by url
        MyModel.from_url "http://localhost/mymodel/1"
        # => instance of MyModel with attributes filled in on 200
        # => nil on 404
        # => raises Harpy::ClientTimeout on timeout
        # => raises Harpy::ClientError on Curl error
        # => raises Harpy::InvalidResponseCode on other response codes

        # Fetch multiple by url in parallel
        MyModel.from_url ["http://localhost/mymodel/1", "http://localhost/mymodel/2"]

        # Get index
        MyModel.search
        # will call GET http://localhost/mymodel given the following entry_point response:
          {
            "link": [
              {"rel": "my_model", "href": "http://localhost/mymodel"}
            ]
          }
        # => return an array of MyModel instances on 200
        # => raises Harpy::ClientTimeout on timeout
        # => raises Harpy::ClientError on Curl error
        # => raises Harpy::InvalidResponseCode on other response codes

        # Search by first_name
        MyModel.search :firstname => "Anthony" # GET http://localhost/mymodel?firstname=Anthony

        # Create (POST)
        model = MyModel.new "firstname" => "Anthony"
        model.save # POST http://localhost/mymodel with {"firstname":"Anthony"}

        # Get an existing resource by url:
        model = MyModel.from_url "http://localhost/mymodel/1"
        # if the service returns the following response:
          {
            "firstname": "Anthony",
            "lastname": null,
            "urn": "urn:mycompany:mymodel:1"
            "link" => [
              {"rel" => "self", "href" => "http://localhost/mymodel/1"},
              {"rel" => "accounts", "href" => "http://localhost/mymodel/1/accounts"}
            ]
          }
        # we can then do:
        model.firstname # => "Anthony"
        model.link "self" # => "http://localhost/mymodel/1"
        model.link :accounts # => "http://localhost/mymodel/1/accounts"

        # Update (PUT) requires resource to have both urn and link to self
        model.attributes = {"firstname" => "Tony"}
        model.save # PUT http://localhost/mymodel/1

        # The resource is persisted once it has an urn:
        model.persisted? # => true

        # If persisted you can no longer read undefined attributes:
        model.lastname # => nil
        model.email # => will raise NoMethodError

* To find a resource by id you need to define `.urn`:

        class MyModel
          include Harpy::Resource
          def self.urn(id)
            "urn:mycompany:mymodel:#{id}"
          end
        end

        model = MyModel.from_id 1 # will GET http://localhost/urn:mycompany:mymodel:1
        # expecting a permanent redirect (301) to follow or not found (404)

* Rel name to search for in entry_point when getting index can be overridden:

        class MyCustomModel
          include Harpy::Resource
          def self.resource_name
            "custom_model"
          end
        end

* or you can use `.with_url(url)` for getting index of nested resources:

        class Account
          include Harpy::Resource
          def users
            User.with_url(link "user") do
              User.search
            end
          end
        end
        class User
          include Harpy::Resource
        end

* you can override `#url_collection` to create nested resources:

        class Account
          include Harpy::Resource
        end
        class User
          include Harpy::Resource
          attr_accessor :account
          def url_collection
            account ? account.link("user") : super
          end
        end

* Fetch multiple resources in parallel:

        class FirstModel
          include Harpy::Resource
        end
        class SecondModel
          include Harpy::Resource
        end

        Harpy::Resource.from_url({
           FirstModel => ["http://localhost/firstmodel/1", "http://localhost/firstmodel/2"],
           SecondModel => ["http://localhost/secondmodel/1"],
        })
        # => {FirstModel => [...], SecondModel => [...]}

License
-------

harpy is Copyright © 2011 TalentBox SA. It is free software, and may be redistributed under the terms specified in the LICENSE file.
