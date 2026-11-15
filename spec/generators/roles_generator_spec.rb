# frozen_string_literal: true

require "rails/generators"
require "generators/rabarber/roles_generator"

RSpec.describe Rabarber::RolesGenerator do
  subject { described_class.start(args) }

  let(:migration_file) { "db/migrate/20221201201056_create_rabarber_roles.rb" }
  let(:id_type) { ActiveRecord::Base.connection.columns(:my_users).find { |column| column.name == "id" }.sql_type }
  let(:migration_content) do
    <<~MIGRATION
      # frozen_string_literal: true

      class CreateRabarberRoles < ActiveRecord::Migration[6.2]
        def change
          create_table :rabarber_roles do |t|
            t.string :name, null: false
            t.belongs_to :context, polymorphic: true, index: true, type: #{id_type.inspect}
            t.timestamps
          end

          add_index :rabarber_roles, [:name, :context_type, :context_id], unique: true

          if connection.supports_partial_index?
            add_index :rabarber_roles, :name, unique: true, where: "context_type IS NULL AND context_id IS NULL"
            add_index :rabarber_roles, [:name, :context_type], unique: true, where: "context_type IS NOT NULL AND context_id IS NULL"
          end

          create_table :rabarber_roles_roleables, id: false do |t|
            t.belongs_to :role, null: false, index: true, foreign_key: { to_table: :rabarber_roles }
            t.belongs_to :roleable, null: false, index: true, foreign_key: { to_table: :my_users, primary_key: primary_key(:my_users) }, type: #{id_type.inspect}
          end

          add_index :rabarber_roles_roleables, [:role_id, :roleable_id], unique: true
        end
      end
    MIGRATION
  end

  before do
    allow(Time).to receive(:now).and_return(Time.new(2022, 12, 1, 21, 10, 56, "+01:00"))
    allow(ActiveRecord::Migration).to receive(:current_version).and_return(6.2)

    ActiveRecord::Base.connection.create_table(:my_users, id: false, force: true) do |t|
      t.string :id, primary_key: true, limit: 36
    end
  end

  after do
    ActiveRecord::Base.connection.drop_table(:my_users)
    FileUtils.rm_rf(Dir.glob("db"))
  end

  shared_examples "a migration generator" do
    before { subject }

    it "generates a properly named migration file" do
      expect(File).to exist(migration_file)
    end

    it "generates a migration file with proper content" do
      expect(File.read(migration_file)).to eq(migration_content)
    end
  end

  context "when only the table name is given" do
    let(:args) { [:my_users] }

    it_behaves_like "a migration generator"
  end

  context "when the table does not exist" do
    let(:args) { [:missing_users] }

    it "stops with an error" do
      expect { subject }.to output("Table `missing_users` does not exist, run its migration first\n").to_stderr
    end

    it "does not generate a migration" do
      expect { subject }.to output.to_stderr
      expect(Dir.glob("db/migrate/*")).to be_empty
    end
  end
end
