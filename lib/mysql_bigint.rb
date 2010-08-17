# MysqlBigint

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

    module SchemaStatements
      def create_table_with_mysql_bigint(name, options = {}, &blk)
        return create_table_without_mysql_bigint(name, options, &blk) unless @connection.class.to_s =~ /mysql/i
        
        unless options[:primary_key].respond_to?(:to_hash)
          options[:primary_key] = {:name => options[:primary_key], :type => :primary_key}
        end

        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key][:name] || "id", options[:primary_key][:type] || :primary_key) unless options[:id] == false

        yield table_definition

        if options[:force]
          drop_table(name) rescue nil
        end

        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{name} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"
        execute create_sql
      end
      alias_method_chain :create_table, :mysql_bigint

      def add_column_options_with_unsigned!(sql, options)
        if options[:unsigned] || (options[:column] && options[:column].unsigned)
          sql << " UNSIGNED"
        end
        add_column_options_without_unsigned!(sql, options)
      end
      alias_method_chain :add_column_options!, :unsigned

      # def type_to_sql(type, limit = nil) #:nodoc:
      # 	      mysql_integer_types = %w{tinyint smallint mediumint integer bigint}
      #   unless self.class.method_defined? :native_database_type
      #     native = native_database_types[type]
      #   else
      #     native = native_database_type(type, limit)
      #     limit = nil if mysql_integer_types.include? native[:name] # mysql doesn't use limit to indicate bytes of storage. 
      # 	              					      # Need to reassign native representation below.
      #   end
      #   limit ||= native[:limit]
      #   column_type_sql = native[:name]
      #   column_type_sql << "(#{limit})" if limit
      #   column_type_sql
      # end
      
      def type_to_sql_with_mysql_bigint(type, *args) #:nodoc:
        return type_to_sql_without_mysql_bigint(type, *args) unless @connection.class.to_s =~ /mysql/i
        limit, precision, scale = *args
        
        mysql_integer_types = %w{tinyint smallint mediumint integer bigint}
        unless self.class.method_defined? :native_database_type
          native = native_database_types[type]
        else
          native = native_database_type(type, limit)
          limit = nil if mysql_integer_types.include? native[:name] # mysql doesn't use limit to indicate bytes of storage.
                					      # Need to reassign native representation below.
        end
        column_type_sql = native[:name]
        if type == :decimal # ignore limit, use precison and scale
          precision ||= native[:precision]
          scale ||= native[:scale]
          if !precision
            raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale if specifed" if scale
          end
          column_type_sql <<
            if scale
              "(#{precision}, #{scale})"
            else
              "(#{precision})"
            end
          column_type_sql
        else
          limit ||= native[:limit]
          column_type_sql << "(#{limit})" if limit
          column_type_sql
        end
      end
      alias_method_chain :type_to_sql, :mysql_bigint
    end

    class MysqlColumn # < Column #:nodoc:
      def extract_limit(sql_type)
        case sql_type
        when /tinyint/ then 1
        when /smallint/ then 2
        when /mediumint/ then 3
        when /bigint/ then 8
        when /int/ then 4
        else
            super
        end
      end
    end

    class MysqlAdapter < AbstractAdapter
      def native_database_types #:nodoc
        {
          :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
          :big_primary_key => "bigint(21) DEFAULT NULL auto_increment PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :tinyint     => { :name => "tinyint", :limit => 1 },
          :smallint    => { :name => "smallint", :limit => 2 },
          :mediumint   => { :name => "mediumint", :limit => 3 },
          :integer     => { :name => "int", :limit => 4 },
          :bigint      => { :name => "bigint", :limit => 8 },
          :decimal     => { :name => "decimal" },
          :float       => { :name => "float" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "tinyint", :limit => 1 }
        }
      end

      def real_native_database_types #:nodoc
        {
          :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
          :big_primary_key => "bigint(21) DEFAULT NULL auto_increment PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :tinyint     => { :name => "tinyint", :limit => 4 },
          :smallint    => { :name => "smallint", :limit => 6 },
          :mediumint   => { :name => "mediumint", :limit => 9 },
          :integer     => { :name => "int", :limit => 11 },
          :bigint      => { :name => "bigint", :limit => 21 },
          :decimal     => { :name => "decimal" },
          :float       => { :name => "float" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "tinyint", :limit => 1 }
        }
      end
      
      def native_database_type(type, limit=nil)
        if type == :integer
          case limit
            when nil then real_native_database_types[:integer]
            when 1 then real_native_database_types[:tinyint]
            when 2  then real_native_database_types[:smallint]
            when 3 then real_native_database_types[:mediumint]
            when 4 then real_native_database_types[:integer]
            else real_native_database_types[:bigint]
          end
        else
          real_native_database_types[type]
        end
      end
    end
  end
end