module ActiveRecord
  module ConnectionAdapters
    class ColumnDefinition
      attr_accessor :unsigned
    end

    class TableDefinition
      def column_with_unsigned(name, type, options = {})
        column_without_unsigned(name, type, options).tap do |column|
          column[name].unsigned = options[:unsigned]
        end
      end
      alias_method_chain :column, :unsigned

      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      # Changed to support the use of bigints as the primary key
      def primary_key_with_mysql_bigint(name, type = :primary_key)
        return primary_key_without_mysql_bigint(name) unless @base.class.to_s =~ /mysql/i

        type = native.fetch(type) do
          options = 'DEFAULT NULL auto_increment ' if type =~ /int/
          "#{type} #{options}PRIMARY KEY"
        end
        column(name, type)
      end
      alias_method_chain :primary_key, :mysql_bigint
    end
  end
end
