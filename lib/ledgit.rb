require 'handler'
require 'account'
require 'index'
require 'ledgit/ledger_file'

class Ledgit
  attr_reader(:accounts)

  def initialize(config_filename)
    json = File.read(config_filename)
    @accounts = JSON.parse(json)['accounts']
    @accounts.map! do |config|
      Account.new(config)
    end
  end

  def run
    accounts.each do |account|
      handler = Handler.get(account)
      handler.run!
    end
  end
end
