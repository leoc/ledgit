# -*- coding: utf-8 -*-
require 'csv'
require 'handler/giro'

class Ledgit
  module Handler
    module DKB
      module Giro
        def login(username, password)
          # log into the online banking website
          @agent.get 'https://banking.dkb.de:443/dkb/-?$javascript=disabled'

          form = @agent.page.forms.first
          form.j_username = username
          form.j_password = password
          form.submit

          # go to the transaction listing for the correct account type
          @agent.page.link_with(text: /Finanzstatus/).click
          @agent.page.link_with(text: /Kontoumsätze/).click
        end

        ##
        # download the transaction data for the specified bank account
        # for the given timespan (fromTransactionDate,
        # toTransactionDate)
        def download_data
          form = @agent.page.forms[2]

          transaction_date = (last_update_at - 3).strftime('%d.%m.%Y')
          to_transaction_date = Date.today.strftime('%d.%m.%Y')

          form.field_with(name: 'slBankAccount').
            option_with(text: /#{Regexp.escape(cardnumber)}/).select
          form.radiobutton_with(name: /searchPeriodRadio/, value: '1').check
          form.field_with(name: 'transactionDate').value = transaction_date
          form.field_with(name: 'toTransactionDate').value = to_transaction_date
          form.submit

          @agent.page.link_with(href: /csvExport/).click
          @agent.page.body
        end

        ##
        # parses the raw data from the DKB website into a hash that
        # ledge_it can work with.
        def parse_data(data)
          data.encode! 'UTF-8', 'ISO-8859-1'
          data.gsub!(/\A.*\n\n.*\n\n/m, '')

          result = CSV.parse(data, col_sep: ';', headers: :first_row)
          result.map do |row|
            {
              booking_date: Date.parse(row['Buchungstag']),
              payment_date:  Date.parse(row['Wertstellung']),
              partner:  row['Auftraggeber / Begünstigter'],
              text:  row['Buchungstext'],
              description:  row['Verwendungszweck'],
              account_number:  row['Kontonummer'],
              bank_code: row['BLZ'],
              amount: row['Betrag (EUR)'].gsub('.', '').gsub(',', '.').to_f
            }
          end
        end
      end
    end
  end
end

Ledgit::Handler.list['dkb/giro'] = [
                                    Ledgit::Handler::DKB::Giro,
                                    Ledgit::Handler::Giro
                                   ]
