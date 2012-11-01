class Ledgit
  class Account < Hash

    attr_reader :name, :cardnumber, :username, :password,
                :ledger_file, :index, :filters

    def initialize hash, index
      @index = index
      @name = hash["name"]
      @cardnumber = hash["cardnumber"]
      @username = hash["username"]
      @password = hash["password"]
      @ledger_file = File.expand_path(hash["ledger_file"])
      @filters = hash["filters"]

      Ledgit::Handler.modules_for(hash["handler"]).each do |mod|
        extend mod
      end
    end

    ##
    # Reads the last update date from the ledger file
    def last_update_at
      File.open(ledger_file, "r") do |file|
        if first_line = file.gets
          if first_line =~ /^; Last Update: ([\d\/]+)$/
            @last_update_at = Date.parse($1)
          end
        end
      end
      @last_update_at ||= Date.today
    end

    ##
    # Writes the last update into the first line of the ledger file.
    def set_last_update!
      File.open(ledger_file, "r+") do |file|
        file.puts "; Last Update: #{Date.today.strftime("%Y/%m/%d")}"
      end
    end

    ##
    # Checks whether the transaction should be filtered or not.
    def filter? transaction
      (filters or []).each do |filter|
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
      FileUtils.touch(ledger_file) unless File.exists?(ledger_file)

      puts "** Last update has been #{last_update_at.strftime('%Y/%m/%d')}"

      puts "** Logging in username: #{username}"
      login username, password

      puts "** Downloading transaction data"
      data = download_data

      puts "** Parsing data"
      dataset = parse_data(data)

      transaction_count = 0
      # Got through
      File.open(ledger_file, "a+") do |file|
        dataset.sort_by{ |hash| hash[:booking_date] }.each do |transaction|
          transaction_count += 1
          print "** Handling transaction [#{transaction_count}/#{data.length}]\r"
          unless transaction_exists?(transaction) or filter?(transaction)
            file.puts create_entry(transaction)
          end
        end
      end

      puts "** Handled #{transaction_count} transactions successfully!"

      set_last_update!
    end
  end
end
