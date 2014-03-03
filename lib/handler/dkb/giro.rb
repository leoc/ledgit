# -*- coding: utf-8 -*-
require 'csv'
require 'handler/giro'

class Ledgit
  module Handler
    module DKB
      module Giro

        def name_for_label(label_text)
          @agent.page.labels.select { |l| l.text =~ /#{label_text}/ }
            .first.node.attribute('for').value
        end

        def login(username, password)
          # log into the online banking website
          @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          @agent.get 'https://banking.dkb.de:443/dkb/-?$javascript=disabled'

          form = @agent.page.forms.first

          form.field_with(name: name_for_label(/Anmeldename/)).value = username
          form.field_with(name: name_for_label(/PIN/)).value = password

          button = form.button_with(value: /Anmelden/)

          @agent.submit(form, button)

          # go to the transaction listing for the correct account type
          @agent.page.link_with(href: /finanzstatus/).click
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

          form.field_with(name: name_for_label(/IBAN/))
            .option_with(text: /#{Regexp.escape(cardnumber)}/).select

          form.radiobuttons[1].check

          date_fields = form.fields_with(value: /\.(#{Date.today.year - 1}|#{Date.today.year}|#{Date.today.year + 1})/)

          date_fields[0].value = transaction_date
          date_fields[1].value = to_transaction_date

          button = form.button_with(value: /Ums.tze anzeigen/)

          @agent.submit(form, button)

          download_form = @agent.page.forms[1]
          download_button = download_form.button_with(value: /CSV-Export/)
          @agent.submit(download_form, download_button)

          @agent.page.body
        end

        ##
        # parses the raw data from the DKB website into a hash that
        # ledge_it can work with.
        def parse_data(data)
          data.encode! 'UTF-8', 'ISO-8859-1'

          data.gsub!(/\A.*\n""\n.*\n""\n/m, '')

          result = CSV.parse(data, col_sep: ';', headers: :first_row)
          result.map do |row|
            {
              booking_date: Date.parse(row['Buchungstag']),
              payment_date:  Date.parse(row['Wertstellung '].insert(6, '20')),
              partner:  row['Auftraggeber / Beguenstigter '],
              text:  row['Buchungstext'],
              description:  row['Verwendungszweck'],
              account_number:  row['Kontonummer'],
              bank_code: row['BLZ'],
              amount: row['Betrag (EUR)'].gsub('.', '').gsub(',', '.').to_f
            }
          end.reverse
        rescue Exception => e
          puts e
          puts e.backtrace
          puts "In dataset: "
        end
      end
    end
  end
end

Ledgit::Handler.list['dkb/giro'] = [
                                    Ledgit::Handler::DKB::Giro,
                                    Ledgit::Handler::Giro
                                   ]
