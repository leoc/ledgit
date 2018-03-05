class Ledgit
  class Account < Hash
    attr_reader(
      :name,
      :ledger_file,
      :handler,
      :filters,
      :credentials
    )

    def initialize(config)
      @name = config['name']
      @ledger_file = config['ledger_file']
      @filters = config['filters']
      @handler = config['handler']
      @credentials = config['credentials']
    end

    ##
    # Checks whether the transaction should be filtered or not.
    def filter?(transaction)
      (filters || []).each do |filter|
        match = true
        filter.each do |key, value|
          match = false if transaction[key.to_sym] !~ /#{value}/
        end
        return true if match
      end
      false
    end

    ##
    # This will do all the work for an account. The data will be
    # fetched and the data will be written to the file.
    def handle!
      puts "* Invoking handler for #{name}"
      @agent = Mechanize.new
      unless File.exists?(ledger_file)
        FileUtils.touch(ledger_file)
        set_last_update!
      end

      puts "** Last update has been #{last_update_at.strftime('%Y/%m/%d')}"

      puts "** Logging in username: #{username}"
      login username, password

      puts '** Downloading transaction data'
      data = download_data

      puts '** Parsing data'
      dataset = parse_data(data)

      transaction_count = 0
      # Got through
      File.open(ledger_file, 'a+') do |file|
        dataset.sort_by { |hash| hash[:booking_date] }.each do |transaction|
          transaction_count += 1
          print "** Handling transaction [#{transaction_count}/#{data.length}]\r"
          unless transaction_exists?(transaction) || filter?(transaction)
            file.puts create_entry(transaction)
          end
        end
      end

      puts "** Handled #{transaction_count} transactions successfully!"

      set_last_update!
    rescue Exception => e
      puts '!! Error handling account'
      puts e
      puts e.backtrace
    end

    def to_s
      "Account<#{name}, file=#{ledger_file}, handler=#{handler}>"
    end
  end
end
