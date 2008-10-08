# MysqlBigint

module ActiveRecord
  module ConnectionAdapters
    class TableDefinition
      # Appends a primary key definition to the table definition.
      # Can be called multiple times, but this is probably not a good idea.
      # Changed to support the use of bigints as the primary key
      def primary_key_with_mysql_bigint(name, use_big_id = false)
        return primary_key_without_mysql_bigint(name) unless @base.class.to_s =~ /mysql/i
        # Use :big_primary_key if it is specified and if it exists for the
        # current adapter.
        key_type = ( use_big_id && !native[:big_primary_key].nil? ) ? :big_primary_key : :primary_key
        column(name, native[key_type])
      end     
      alias_method_chain :primary_key, :mysql_bigint
    end

    module SchemaStatements
      def create_table_with_mysql_bigint(name, options = {}, &blk)
        return create_table_without_mysql_bigint(name, options, &blk) unless @connection.class.to_s =~ /mysql/i
        
        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || "id", options[:use_big_id] || false) unless options[:id] == false

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
          if precision
            if scale
              column_type_sql << "(#{precision}, #{scale})"
            else
              column_type_sql << "(#{precision})"
            end
          else
            raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale if specifed" if scale
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
          when /tinyint/ then return 1
          when /smallint/ then return 2
          when /mediumint/ then return 3
          when /bigint/ then return 8
          when /int/ then return 4
        end
        super
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
          native_type = case limit
                          when nil then real_native_database_types[:integer]
                          when 1 then real_native_database_types[:tinyint]
                          when 2  then real_native_database_types[:smallint]
                          when 3 then real_native_database_types[:mediumint]
                          when 4 then real_native_database_types[:integer]
                          else real_native_database_types[:bigint]
                        end
        else native_type = real_native_database_types[type]
        end
        native_type
      end
    end
  end
end