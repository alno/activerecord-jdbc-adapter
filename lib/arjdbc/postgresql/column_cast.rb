module ArJdbc
  module PostgreSQL
    module Column
      # based on active_record/connection_adapters/postgresql/cast.rb
      module Cast

        def string_to_time(string)
          return string unless String === string

          case string
          when 'infinity'; 1.0 / 0.0
          when '-infinity'; -1.0 / 0.0
          when / BC$/
            super("-" + string.sub(/ BC$/, ""))
          else
            super
          end
        end

        def hstore_to_string(object)
          if Hash === object
            object.map { |k,v|
              "#{escape_hstore(k)}=>#{escape_hstore(v)}"
            }.join ','
          else
            object
          end
        end

        def string_to_hstore(string)
          if string.nil?
            nil
          elsif String === string
            Hash[string.scan(HstorePair).map { |k,v|
              v = v.upcase == 'NULL' ? nil : v.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              k = k.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              [k,v]
            }]
          elsif Java::JavaUtil::HashMap === string
            string.to_hash
          else
            string
          end
        end

        def json_to_string(object)
          if Hash === object || Array === object
            ActiveSupport::JSON.encode(object)
          else
            object
          end
        end

        def array_to_string(value, column, adapter, should_be_quoted = false)
          casted_values = value.map do |val|
            if val == "NULL"
              "\"#{val}\""
            elsif Array === val # Special handling of multidimensional arrays
              adapter.type_cast(val, column, true)
            else
              casted_val = adapter.type_cast(val, column, true)

              if String === casted_val
                quote_and_escape(casted_val)
              else
                casted_val
              end
            end
          end
          "{#{casted_values.join(',')}}"
        end

        def range_to_string(object)
          from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
          to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
          "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
        end

        def string_to_json(string)
          if String === string
            ActiveSupport::JSON.decode(string)
          else
            string
          end
        end

        def string_to_cidr(string)
          if string.nil?
            nil
          elsif String === string
            IPAddr.new(string)
          else
            string
          end
        end

        def cidr_to_string(object)
          if IPAddr === object
            "#{object.to_s}/#{object.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
          else
            object
          end
        end

        # NOTE: not used - we get "parsed" array value from connection
        #def string_to_array(string, oid)
        #  parse_pg_array(string).map { |val| oid.type_cast val }
        #end

        private

          HstorePair = begin
            quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
            unquoted_string = /(?:\\.|[^\s,])[^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
            /(#{quoted_string}|#{unquoted_string})\s*=>\s*(#{quoted_string}|#{unquoted_string})/
          end

          def escape_hstore(value)
            if value.nil?
              'NULL'
            else
              if value == ""
                '""'
              else
                '"%s"' % value.to_s.gsub(/(["\\])/, '\\\\\1')
              end
            end
          end

          def quote_and_escape(value)
            case value
            when "NULL"
              value
            else
              "\"#{value.gsub(/(["\\])/, '\\\\\1')}\""
            end
          end

      end
    end
  end
end
