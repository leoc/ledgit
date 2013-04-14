class Ledgit
  module Handler
    module CreditCard

      def load_for_index?
        false
      end

      def transaction_exists? transaction
        `cat "#{ledger_file}" | sed -n -e '/^#{transaction[:booking_date].strftime("%Y\\/%m\\/%d")}/,/^$/{/description: #{transaction[:description].strip.gsub('*', '\*')}/p}'` != ""
      end

      def create_entry transaction
        buffer = StringIO.new

        buffer.puts
        buffer.puts "#{transaction[:booking_date].strftime("%Y/%m/%d")}=#{transaction[:payment_date].strftime("%Y/%m/%d")} * #{transaction[:description]}"

        if transaction[:amount] > 0
          account_name = 'Income:Unknown'
          buffer.puts "    #{name}  #{"%.2f" % transaction[:amount]}EUR"
          buffer.puts "    #{account_name}"
        elsif transaction[:amount] < 0
          account_name = 'Expenses:Unknown'
          buffer.puts "    #{account_name}  #{"%.2f" % (-1.00*transaction[:amount])}EUR"
          buffer.puts "    #{name}"
        end

        buffer.puts "      ; description: #{transaction[:description]}"
        buffer.string
      end

    end
  end
end
