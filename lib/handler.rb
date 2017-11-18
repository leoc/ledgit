require 'digest/sha1'

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
      transactions.each do |transaction|
        transaction[:id] ||= calculate_transaction_id(transaction)
      end

      puts "Appending transactions to file ..."
      transactions.each do |transaction|
        next if filter_transaction?(transaction)
        next if transaction_exists?(transaction)
        file.append_transaction(transaction)
      end

      puts "Finishing up ..."
      file.set_last_update!
    end

    def filter_transaction?(transaction, filters = account.filters)
      (filters || []).any? do |filter|
        filter.all? do |key, value|
          tags = transaction[:tags] || {}
          tags[key.to_sym] == value
        end
      end
    end

    def calculate_transaction_id(transaction)
      str = transaction[:payment_date].strftime('%Y%m%d')
      str += transaction[:payee]
      str += (transaction[:tags] || {}).sort.to_h.values.join
      Digest::SHA1.hexdigest(str)
    end

    def transaction_exists?(transaction)
      `cat "#{file.filename}" | grep -q "  ; transaction_id: #{transaction[:id]}"`
      $?.exitstatus == 0
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
