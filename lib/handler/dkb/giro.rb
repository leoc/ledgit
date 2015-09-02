# -*- coding: utf-8 -*-
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

          form.field_with(name: 'j_username').value = username
          form.field_with(name: 'j_password').value = password

          button = form.button_with(name: '$$event_login')

          @agent.submit(form, button)

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

          form.field_with(id: /slBankAccount/)
            .option_with(text: /#{Regexp.escape(cardnumber)}/).select

          form.radiobuttons[1].check

          date_fields = []
          date_fields[0] = form.fields_with(id: name_for_label(/vom/)).first
          date_fields[1] = form.fields_with(name: name_for_label(/bis/)).first

          date_fields[0].value = transaction_date
          date_fields[1].value = to_transaction_date

          button = form.button_with(id: 'searchbutton')

          @agent.submit(form, button)

          download_link = @agent.page.link_with(href: /event=csvExport/)
          download_link.click

          @agent.page.body
        end

        ##
        # parses the raw data from the DKB website into a hash that
        # ledge_it can work with.
        def parse_data(data)
          data.encode! 'UTF-8', 'ISO-8859-1'

          data.gsub!(/\A.*\n""\n.*\n""\n/m, '')

          first_line = 0
          data.lines.each_with_index do |line, index|
            if line.start_with?('"Buchungstag"')
              first_line = index
              break
            end
          end

          data = data.lines.drop(first_line).join('')

          result = CSV.parse(data, col_sep: ';', headers: :first_row)
          groups = {}
          result.each do |row|
            booking_date = Date.parse(row['Buchungstag'])
            payment_date = Date.parse(row['Wertstellung'])
            if booking_date == payment_date
              (groups[payment_date] ||= []) << {
                booking_date: booking_date,
                payment_date: payment_date,
                partner:  row['Auftraggeber / Begünstigter'],
                text:  row['Buchungstext'],
                description:  row['Verwendungszweck'],
                account_number:  row['Kontonummer'],
                bank_code: row['BLZ'],
                amount: row['Betrag (EUR)'].gsub('.', '').gsub(',', '.').to_f
              }
            end
          end
          result = groups.keys.sort.map { |date| groups[date].reverse }.flatten
        end
      end
    end
  end
end

Ledgit::Handler.list['dkb/giro'] = [Ledgit::Handler::DKB::Giro, Ledgit::Handler::Giro]
