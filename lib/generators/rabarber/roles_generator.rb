# frozen_string_literal: true

require "rails/generators/migration"

module Rabarber
  class RolesGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    argument :table_name, type: :string, required: true

    def create_migrations
      primary_key = ActiveRecord::Base.with_connection do |connection|
        raise Thor::Error, "Table `#{table_name}` does not exist, run its migration first" unless connection.table_exists?(table_name)

        connection.columns(table_name).find { |column| column.name == connection.primary_key(table_name) }
      end

      @id_type = primary_key.sql_type
      @roles_id_type = @id_type unless primary_key.auto_incremented_by_db?
      @roles_id_default = primary_key.default_function if @roles_id_type

      migration_template "create_rabarber_roles.rb.erb", "db/migrate/create_rabarber_roles.rb"
    end

    def self.next_migration_number(_path)
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
  end
end
