# -*- coding: utf-8 -*-
require 'csv'

class Ledgit
  class Handler
    class DKB
      class Creditcard < Ledgit::Handler
        def get_transactions
          download_csv_transactions
            .map(&method(:map_csv_transaction))
            .reverse
        end

        def map_csv_transaction(transaction)
          amount = transaction['Betrag (EUR)']
          currency = 'EUR'
          converted_amount = nil
          converted_currency = nil
          original_amount = transaction['Ursprünglicher Betrag']
          unless original_amount.to_s.strip.empty?
            converted_amount = amount
            converted_currency = currency
            amount, currency = original_amount.split(' ')
          end

          {
            payee: transaction['Beschreibung'],
            booking_date: Date.parse(transaction['Belegdatum']),
            payment_date: Date.parse(transaction['Wertstellung']),
            tags: {
              description: transaction['Beschreibung']
            },
            postings: [
              {
                account: receiving_account(transaction),
                amount: norm(amount),
                currency: currency,
                converted_amount: norm(converted_amount),
                converted_currency: converted_currency
              }, {
                account: sending_account(transaction),
                amount: "-#{norm(amount)}",
                currency: currency,
                converted_amount: norm(converted_amount),
                converted_currency: converted_currency
              }
            ]
          }
        end

        def norm(amount)
          return if amount.nil?
          if amount[0] == '-'
            amount[1..-1].tr(',', '.')
          else
            amount.tr(',', '.')
          end
        end

        def receiving_account(transaction)
          if transaction['Betrag (EUR)'][0] == '-'
            'Expenses:Unknown'
          else
            account.name
          end
        end

        def sending_account(transaction)
          if transaction['Betrag (EUR)'][0] == '-'
            account.name
          else
            'Income:Unknown'
          end
        end

        private

        def download_csv_transactions
          @agent = Mechanize.new

          # log into the online banking website
          @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          @agent.get 'https://banking.dkb.de:443/dkb/-?$javascript=disabled'
          form = @agent.page.forms[1]

          form.field_with(name: 'j_username').value = account.credentials['username']
          form.field_with(name: 'j_password').value = account.credentials['password']

          button = form.button_with(type: 'submit')

          @agent.submit(form, button)

          # go to the transaction listing for the correct account type
          @agent.page.link_with(text: /Umsätze/).click

          form = @agent.page.forms[2]

          transaction_date = (file.last_update_at - 5).strftime('%d.%m.%Y')
          to_transaction_date = Date.today.strftime('%d.%m.%Y')

          safe_cardnumber = account.credentials['cardnumber'].dup
          safe_cardnumber[4...12] = '*' * 8

          form
            .field_with(type: nil, name: /slAllAccounts/)
            .option_with(text: /#{Regexp.escape(safe_cardnumber)}/)
            .select

          form.submit

          form = @agent.page.forms[2]

          form.radiobuttons[1].check

          form.field_with(name: /postingDate/).value = transaction_date
          form.field_with(name: /toPostingDate/).value = to_transaction_date

          form.submit

          @agent.page.link_with(href: /csvExport/).click
          csv_data = @agent.page.body
          csv_data.encode!('UTF-8', 'ISO-8859-1')
          csv_data.gsub!(/\A.*\n\n.*\n\n/m, '')

          CSV.parse(csv_data, col_sep: ';', headers: :first_row)
        end
      end
    end
  end
end
