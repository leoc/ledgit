class Ledgit
  module Handler

    class << self

      def list
        @list ||= {}
      end

      def get_class key
        klass = list[key]
        raise "no such handler for '#{key}'" unless klass
        klass
      end

    end

    module ClassMethods
      def prop
        @properties
      end

      def get_data from_date = nil, to_date = nil
        puts "** Logging in username: #{prop[:username]}"
        login(prop[:username], prop[:password])
        puts "** Downloading transaction for timespan: #{from_date.strftime('%Y/%m/%d')} to #{to_date.strftime('%Y/%m/%d')}"
        data = download_data(from_date, to_date)
        puts "** Parsing data"
        parse_data(data)
      end
    end

  end
end
