require 'fileutils'

class Ledgit
  class LedgerFile
    attr_reader(:filename)

    def initialize(filename)
      @filename = File.expand_path(filename)

      return if File.exist?(filename)
      FileUtils.touch(filename)
      set_last_update!
    end

    def last_update_at
      File.open(filename, 'r') do |file|
        first_line = file.gets
        if first_line && first_line =~ /^; Last Update: ([\d\/]+)$/
          @last_update_at = Date.parse($1)
        end
      end
      @last_update_at ||= Date.today
    end

    def set_last_update!
      File.open(filename, 'r+') do |file|
        file.puts "; Last Update: #{Date.today.strftime("%Y/%m/%d")}"
      end
    end

    def append_transaction(transaction)
      File.open(filename, 'a+') do |file|
        file.puts
        file.puts(format_transaction(transaction))
      end
    end

    def transaction_exists?(transaction)
      false
    end

    def format_transaction(transaction)
      str = ""
      str += "#{transaction[:booking_date].strftime('%Y/%m/%d')}"
      str += "=#{transaction[:payment_date].strftime('%Y/%m/%d')}" if transaction[:payment_date]
      str += " * "
      str += transaction[:payee]
      str += "\n"
      (transaction[:tags] || {}).each_pair do |key, value|
        next if value.nil?
        str += "  ; #{key}: #{value}\n"
      end
      (transaction[:postings] || []).each do |posting|
        str += "  #{posting[:account]}  #{posting[:amount]} #{posting[:currency]}"
        if posting[:converted_amount]
          str += " @@ #{posting[:converted_amount]} #{posting[:converted_currency]}" 
        end
        str += "\n"
      end
      str
    end
  end
end
