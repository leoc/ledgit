# -*- coding: utf-8 -*-
require 'handler'
require 'handler/dkb'

class Ledgit

  def initialize config_filename
    json = File.read(config_filename)
    @accounts = JSON.parse(json)["accounts"]
    @accounts.map! do |account|
      account.keys.each do |key|
        if key.to_sym == :ledger_file
          account[key.to_sym] = File.expand_path(account.delete(key))
        else
          account[key.to_sym] = account.delete(key)
        end
      end
      account
    end
  end

  def index
    @index ||= {}
  end

  def run
    load_index
    @accounts.each do |account|
      handle_account account
    end
  end

  def handle_account prop
    puts "* Invoking handler for #{prop[:name]}"
    # find handler for account
    klass = Handler.get_class prop[:handler]
    handler = klass.new prop

    # Get the date of the last update for that account. By convention
    # it is in the first line of the ledger file.
    last_update_at = Date.today
    File.open(prop[:ledger_file], "r") do |file|
      if first_line = file.gets
        last_update_at = Date.parse(first_line.match(/^; Last Update: ([\d\/]+)$/)[1])
      end
    end
    puts "** Last update has been #{last_update_at.strftime('%Y/%m/%d')}"

    # download csv
    data = handler.get_data last_update_at, Date.today

    i = 0
    # go through transactions and create the ledger entry based on
    File.open(prop[:ledger_file], "a") do |file|
      data.sort{ |a, b| a[:booking_date] <=> b[:booking_date] }.each do |transaction|
        i += 1
        print "** Handling transaction [#{i}/#{data.length}]\r"

        # look if this transaction already has been processed
        grep_result = `cat #{prop[:ledger_file]} | grep -a5 ^#{transaction[:booking_date].strftime("%Y/%m/%d")} | grep -B5 -A2 "transaction_partner: #{transaction[:partner].strip.gsub('*', '\*')}" | grep "#{transaction[:description].strip.gsub('*', '\*')}"`

        # look for earlier transactions with that transaction partner
        if grep_result == ""
          partner_name = (get_partner_name(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or transaction[:partner])

          buffer = StringIO.new
          buffer.puts
          buffer.puts "#{transaction[:booking_date].strftime("%Y/%m/%d")}=#{transaction[:payment_date].strftime("%Y/%m/%d")} * #{partner_name}"

          if transaction[:amount] > 0
            account_name = (get_subtraction_account(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or 'Income:Unknown')
            buffer.puts "    #{prop[:name]}  #{"%.2f" % transaction[:amount]}EUR"
            buffer.puts "    #{account_name}"
          elsif transaction[:amount] < 0
            account_name = (get_addition_account(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or 'Expenses:Unknown')
            buffer.puts "    #{account_name}  #{"%.2f" % (-1.00*transaction[:amount])}EUR"
            buffer.puts "    #{prop[:name]}"
          end
          buffer.puts "      ; transaction_partner: #{transaction[:partner]}"
          buffer.puts "      ; transaction_description: #{transaction[:description]}"
          buffer.puts "      ; transaction_account_number: #{transaction[:account_number]}"
          buffer.puts "      ; transaction_bank_code: #{transaction[:bank_code]}"

          file.puts buffer.string
        end
      end
    end

    File.open(prop[:ledger_file], "r+") do |file|
      file.puts "; Last Update: #{Date.today.strftime("%Y/%m/%d")}"
    end
    puts "** Handled #{i} transactions successfully!"
  end

  private
  ##
  # Loads an index of used ledger accounts and transaction names from
  # all account files
  def load_index
    @accounts.each do |account|
      transaction = nil
      File.open(account[:ledger_file], 'r').each_line do |line|
        # read each transaction
        if transaction
          if line =~ /^[ ]+([\w: ]+?)  ([\d.]+)EUR$/
            unless $1 == account[:name]
              transaction[:add_accounts] ||= {}
              transaction[:add_accounts][$1] ||= 0
              transaction[:add_accounts][$1] += 1
            end
          elsif line =~ /^[ ]+([\w: ]+?)$/
            unless $1 == account[:name]
              transaction[:sub_accounts] ||= {}
              transaction[:sub_accounts][$1] ||= 0
              transaction[:sub_accounts][$1] += 1
            end
          elsif line =~ /^[ ]+; transaction_partner: (.*)$/
            transaction[:partner] = $1
          elsif line =~ /^[ ]+; transaction_account_number: (.*)$/
            transaction[:account_number] = $1
          elsif line =~ /^[ ]+; transaction_bank_code: (.*)$/
            transaction[:bank_code] = $1
          elsif line =~ /^$/
            add_to_index transaction
            transaction = nil
          end
        else
          if line =~ /^\d+\/\d+\/\d+(=\d+\/\d+\/\d+)?( . | )(.*)$/
            transaction = {}
            transaction[:name] = $3
          end
        end
      end
      add_to_index transaction if transaction
    end
  end

  def add_to_index transaction
    entry = (index["#{transaction[:partner]}-#{transaction[:account_number]}-#{transaction[:bank_code]}"] ||= {})

    entry[:names] ||= {}
    entry[:names][transaction[:name]] =
      (entry[:names][transaction[:name]] or 0) + 1

    (transaction[:add_accounts] or {}).each_pair do |account, count|
      entry[:add_accounts] ||= {}
      entry[:add_accounts][account] =
        (entry[:add_accounts][account] or 0) + count
    end

    (transaction[:sub_accounts] or {}).each_pair do |account, count|
      entry[:sub_accounts] ||= {}
      entry[:sub_accounts][account] =
        (entry[:sub_accounts][account] or 0) + count
    end
  end

  def get_partner_name partner, account_number, bank_code
    entry = index["#{partner}-#{account_number}-#{bank_code}"]
    current_name = nil
    if entry
      highest = 0
      (entry[:names] or {}).each_pair do |name, count|
        current_name = name if count > highest
      end
    end
    current_name
  end

  def get_subtraction_account partner, account_number, bank_code
    entry = index["#{partner}-#{account_number}-#{bank_code}"]
    current_account = nil
    if entry
      highest = 0
      (entry[:sub_accounts] or {}).each_pair do |account, count|
        current_account = account if count > highest
      end
    end
    current_account
  end

  def get_addition_account partner, account_number, bank_code
    entry = index["#{partner}-#{account_number}-#{bank_code}"]
    current_account = nil
    if entry
      highest = 0
      (entry[:add_accounts] or {}).each_pair do |account, count|
        current_account = account if count > highest
      end
    end
    current_account
  end
end
