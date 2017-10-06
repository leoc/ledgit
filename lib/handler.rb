class Ledgit
  class Handler
    attr_reader(:account, :file)

    def initialize(account)
      @account = account
      @file = Ledgit::LedgerFile.new(account.ledger_file)
    end

    def get_transactions
      raise('Running blank handler. Use bank specific handlers.')
    end

    def run!
      puts "Running handler for #{account} ..."
      file = LedgerFile.new(account.ledger_file)

      puts "Retrieving transactions ..."
      transactions = get_transactions

      puts "Appending transactions to file ..."
      transactions.each do |transaction|
        file.append_transaction(transaction)
      end

      puts "Finishing up ..."
      file.set_last_update!
    end

    def self.list
      @list ||= {}
    end

    def self.[](key)
      list[key] || raise("no such handler for '#{key}'")
    end

    def self.inherited(handler_class)
      return if handler_class.to_s !~ /Ledgit::Handler::/
      identifier =
        handler_class
          .to_s
          .gsub('Ledgit::Handler::', '')
          .gsub('::', '/')
          .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr('-', '_')
          .downcase
      Handler.list[identifier] = handler_class
    end

    def self.get(account)
      handler_class = Handler[account.handler]
      handler_class.new(account)
    end
  end
end

Dir["#{File.dirname(__FILE__)}/handler/**/*.rb"].each { |file| require(file) }
