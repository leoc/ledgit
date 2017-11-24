# -*- coding: utf-8 -*-
require 'csv'

class Ledgit
  class Handler
    class DKB
      class Giro < Ledgit::Handler
        def transaction_id_tags
          %i(partner description account_number bank_code)
        end

        def get_transactions
          transactions = download_csv_transactions
          transactions
            .map(&method(:map_csv_transaction))
            .reverse
        end

        def map_csv_transaction(transaction)
          amount = transaction['Betrag (EUR)']
          currency = 'EUR'
          {
            payee: transaction['Auftraggeber / Begünstigter'],
            booking_date: Date.parse(transaction['Buchungstag']),
            payment_date: Date.parse(transaction['Wertstellung']),
            tags: {
              partner: transaction['Auftraggeber / Begünstigter'],
              description: transaction['Verwendungszweck'],
              account_number: transaction['Kontonummer'],
              bank_code: transaction['BLZ'],
              booking_text: transaction['Buchungstext']
            },
            postings: [
              {
                account: receiving_account(transaction),
                amount: norm(amount),
                currency: currency
              }, {
                account: sending_account(transaction),
                amount: "-#{norm(amount)}",
                currency: currency
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
          # @agent.page.link_with(text: /Finanzstatus/).click
          @agent.page.link_with(text: /Umsätze/).click

          form = @agent.page.forms[2]

          transaction_date = (file.last_update_at - 3).strftime('%d.%m.%Y')
          to_transaction_date = Date.today.strftime('%d.%m.%Y')

          iban = account.credentials['iban']
          iban.delete!(' ')
          iban
            .insert(4, ' ')
            .insert(9, ' ')
            .insert(14, ' ')
            .insert(19, ' ')
            .insert(24, ' ')

          form.field_with(type: nil, name: /slAllAccounts/).option_with(text: /#{Regexp.escape(iban)}/).select

          form.radiobuttons[1].check

          form.field_with(name: /transactionDate/).value = transaction_date
          form.field_with(name: /toTransactionDate/).value = to_transaction_date

          button = form.button_with(id: 'searchbutton')

          @agent.submit(form, button)

          @agent.page.link_with(href: /event=csvExport/).click

          csv_data = @agent.page.body

          csv_data.encode! 'UTF-8', 'ISO-8859-1'
          csv_data.gsub!(/\A.*\n\n.*\n\n/m, '')
          CSV.parse(csv_data, col_sep: ';', headers: :first_row)
        end
      end
    end
  end
end
