# -*- coding: utf-8 -*-
require "csv"
require "handler/giro"
require "pry"

class Ledgit
  module Handler
    module Sparkasse
      module MOL
        module Giro

          def name_for_label(label_text)
            @agent.page.labels.select { |l| l.text =~ /#{label_text}/ }
              .first.node.attribute('for').value
          end

          def login(username, password)
            cert_store = OpenSSL::X509::Store.new
            cert_store.add_file File.dirname(File.expand_path(__FILE__)) + '/verisign.crt'

            @agent.cert_store = cert_store
            @agent.get 'https://banking.sparkasse-mol.de'

            form = @agent.page.forms[1]
            form.field_with(name: name_for_label('Anmeldename')).value = username
            form.field_with(name: name_for_label('PIN:')).value = password
            form.submit

            @agent.page.link_with(text: /Umsätze/).click
          end

          ##
          # download the transaction data for the specified bank account
          # for the given timespan (fromTransactionDate,
          # toTransactionDate)
          def download_data
            form = @agent.page.forms[3]

            transaction_date = (last_update_at - 3).strftime('%d.%m.%Y')
            to_transaction_date = Date.today.strftime('%d.%m.%Y')

            form.field_with(name: name_for_label(/Konto\*:/))
              .option_with(text: /#{Regexp.escape(cardnumber)}/).select
            form.radiobutton_with(value: 'zeitraumDatum').check
            form.field_with(name: name_for_label(/von:/)).value = transaction_date
            form.field_with(name: name_for_label(/bis:/)).value = to_transaction_date
            @agent.submit(form, form.button_with(value: /Aktualisieren/))

            @agent.submit(form, form.button_with(value: /Export/))
            @agent.page.body
          end

          ##
          # parses the raw data from the DKB website into a hash that
          # ledge_it can work with.
          def parse_data(data)
            data.encode! 'UTF-8', 'ISO-8859-1'

            result = CSV.parse(data, col_sep: ';', headers: :first_row)
            result.map do |row|
              booking_date = if row['Buchungstag'].length < 8
                               "#{row['Buchungstag'][0..1]}.#{row['Buchungstag'][3..4]}.#{Date.today.year}"
                             else
                               "#{row['Buchungstag'][0..1]}.#{row['Buchungstag'][3..4]}.20#{row['Buchungstag'][6..7]}"
                             end
              payment_date = if row['Valutadatum'].length < 8
                               "#{row['Valutadatum'][0..1]}.#{row['Valutadatum'][3..4]}.20#{Date.today.year}"
                             else
                               "#{row['Valutadatum'][0..1]}.#{row['Valutadatum'][3..4]}.20#{row['Valutadatum'][6..7]}"
                             end


              {
                booking_date: begin
                                Date.parse(booking_date)
                              rescue
                                Date.parse(payment_date)
                              end,
                payment_date: begin
                                Date.parse(payment_date)
                              rescue
                                Date.parse(booking_date)
                              end,
                partner:  row['Begünstigter/Zahlungspflichtiger'],
                text:  row['Buchungstext'],
                description:  row['Verwendungszweck'],
                account_number:  row['Kontonummer'],
                bank_code: row['BLZ'],
                amount: row['Betrag'].gsub('.', '').gsub(',', '.').to_f
              }
            end
          rescue Exception => e
            puts 'Something happened while trying to parse CSV data.'
            puts e
            puts e.backtrace
          end
        end
      end
    end
  end
end

Ledgit::Handler.list['sparkasse/mol/giro'] = [
                                              Ledgit::Handler::Giro,
                                              Ledgit::Handler::Sparkasse::MOL::Giro
                                             ]
