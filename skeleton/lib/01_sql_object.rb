require_relative 'db_connection'
require 'active_support/inflector'
require "byebug"
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject

  def self.columns
    return @columns unless  @columns.nil?
    db_cols= DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}

    SQL
     cols = db_cols.map!{ |col| col.to_sym }
    @columns = cols

  end

  def self.finalize!
    self.columns.each do |col|
      define_method(col) do
        self.attributes[col]
      end

      define_method("#{col}=") do |val|
        self.attributes[col] = val
      end
    end
  end


  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.to_s.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL
    parse_all(results)

  end

  def self.parse_all(results)
    results.map { |el| self.new(el) }
  end

  def self.find(id)
    results =  DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL
    return nil if results.empty?
    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, value |
      attr_name = attr_name.to_sym
      if self.class.columns.include?(attr_name)
        self.send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
    @params = params
  end

  def attributes
    @attributes ||= {}
    # ...
  end

  def attribute_values
    @attributes.values
    # ...
  end

  def insert

    size = self.class.columns.size - 1
    col_names = self.class.columns[1..-1].join(", ")
    question_marks =(["?"] * size).join(", ")
      DBConnection.execute(<<-SQL, @attributes.values)
      INSERT INTO
      #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
      self.id = DBConnection.last_insert_row_id
    end

  def update
    col_name = self.class.columns.map{|el| "#{el} = ?"  }.join(", ")
    DBConnection.execute(<<-SQL, @attributes.values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_name}
      WHERE
        #{self.class.table_name}.id = ?
    SQL
    # ...
  end

  def save
       id.nil? ? insert : update
  end
end
