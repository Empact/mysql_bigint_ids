module ActiveRecord
  module ConnectionAdapters
    class ColumnDefinition
      attr_accessor :unsigned
    end

    module UnsignedTableSupport
      def column(name, type, options = {})
        super.tap do |column|
          column[name].unsigned = options[:unsigned]
        end
      end
    end

    module BigIntTableSupport
      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      # Changed to support the use of bigints as the primary key
      def primary_key(name, type = :primary_key)
        return super(name) unless @base.class.to_s =~ /mysql/i

        type = native.fetch(type) do
          options = 'DEFAULT NULL auto_increment ' if type =~ /int/
          "#{type} #{options}PRIMARY KEY"
        end
        column(name, type)
      end
    end

    class TableDefinition
      include BigIntTableSupport, UnsignedTableSupport
    end
  end
end
