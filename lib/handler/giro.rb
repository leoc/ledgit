class Ledgit
  module Handler
    module Giro

      def load_for_index?
        true
      end

      def transaction_exists?(transaction)
        `cat "#{ledger_file}" | sed -n -e '/^#{transaction[:booking_date].strftime("%Y\\/%m\\/%d")}/,/^$/{/transaction_partner: #{transaction[:partner].strip.gsub('*', '\*').gsub('/', '\/')}/,/transaction_description: #{transaction[:description].strip.gsub('*', '\*').gsub('/', '\/')}/p}'` != ""
      end

      def create_entry(transaction)
        partner_name = (index.get_partner_name(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or transaction[:partner])

        buffer = StringIO.new

        buffer.puts
        buffer.puts "#{transaction[:booking_date].strftime("%Y/%m/%d")}=#{transaction[:payment_date].strftime("%Y/%m/%d")} * #{partner_name}"

        if transaction[:amount] > 0
          account_name = (index.get_subtraction_account(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or 'Income:Unknown')
          buffer.puts "    #{name}  #{"%.2f" % transaction[:amount]}EUR"
          buffer.puts "    #{account_name}"
        elsif transaction[:amount] < 0
          account_name = (index.get_addition_account(transaction[:partner], transaction[:account_number], transaction[:bank_code]) or 'Expenses:Unknown')
          buffer.puts "    #{account_name}  #{"%.2f" % (-1.00*transaction[:amount])}EUR"
          buffer.puts "    #{name}"
        end

        buffer.puts "      ; transaction_partner: #{transaction[:partner]}"
        buffer.puts "      ; transaction_description: #{transaction[:description]}"
        buffer.puts "      ; transaction_account_number: #{transaction[:account_number]}"
        buffer.puts "      ; transaction_bank_code: #{transaction[:bank_code]}"
        buffer.string
      end

    end
  end
end
