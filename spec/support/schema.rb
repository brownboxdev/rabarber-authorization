# frozen_string_literal: true

require "rails/generators"
require "generators/rabarber/roles_generator"
require "tmpdir"

ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  drop_table :rabarber_roles_roleables, if_exists: true
  drop_table :rabarber_roles, if_exists: true

  [:users, :clients, :projects].each do |table|
    next create_table(table, force: true, &:timestamps) unless ENV["UUID_TESTS"] == "true"

    if connection.adapter_name == "PostgreSQL"
      create_table table, id: :uuid, force: true, &:timestamps
    else
      create_table table, id: :string, limit: 36, force: true, &:timestamps
    end
  end
end

Dir.mktmpdir do |dir|
  Rabarber::RolesGenerator.start(["users", "--quiet"], destination_root: dir)
  load Dir["#{dir}/db/migrate/*.rb"].first
end

CreateRabarberRoles.migrate(:up)
