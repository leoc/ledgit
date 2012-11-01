# -*- coding: utf-8 -*-
require 'handler'
require 'account'
require 'index'

class Ledgit

  def initialize config_filename
    json = File.read(config_filename)
    @accounts = JSON.parse(json)["accounts"]
    @accounts.map! do |hash|
      Account.new hash, index
    end
  end

  def index
    @index ||= Index.new
  end

  def run
    index.load @accounts
    @accounts.each do |account|
      account.handle!
    end
  end
end
