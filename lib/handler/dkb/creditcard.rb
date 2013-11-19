# -*- coding: utf-8 -*-
require 'csv'
require 'handler/creditcard'

class Ledgit
  module Handler
    module DKB
      module CreditCard

        def name_for_label(label_text)
          @agent.page.labels.select { |l| l.text =~ /#{label_text}/ }
            .first.node.attribute('for').value
        rescue Exception => e
          binding.pry
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
          @agent.page.link_with(text: /Kreditkartenumsätze/).click
          unless @agent.page.meta_refresh.empty?
            @agent.page.meta_refresh.first.click
          end
        end

        ##
        # download the transaction data for the specified bank account
        # for the given timespan (fromTransactionDate,
        # toTransactionDate)
        def download_data
          form = @agent.page.forms[2]

          posting_date = (last_update_at - 35).strftime('%d.%m.%Y')
          to_posting_date = Date.today.strftime('%d.%m.%Y')

          form.field_with(name: /slCreditCard/)
            .option_with(text: /#{Regexp.escape(cardnumber)}/).select

          form.radiobutton_with(name: /searchPeriod/, value: '0').check
          form.field_with(name: 'postingDate').value = posting_date
          form.field_with(name: 'toPostingDate').value = to_posting_date
          form.submit

          @agent.page.link_with(href: /csvExport/).click
          @agent.page.body
        end

        ##
        # parses the raw data from the DKB website into a hash that
        # ledge_it can work with.
        def parse_data(data)
          data.encode!('UTF-8', 'ISO-8859-1')
          data.gsub!(/\A.*\n\n.*\n\n/m, '')

          result = CSV.parse(data, col_sep: ';', headers: :first_row)
          result.map do |row|
            {
              booking_date: Date.parse(row['Belegdatum']),
              payment_date:  Date.parse(row['Wertstellung']),
              description:  row['Umsatzbeschreibung'],
              amount: row['Betrag (EUR)'].gsub('.', '').gsub(',', '.').to_f
            }
          end.reverse
        end
      end
    end
  end
end

Ledgit::Handler.list['dkb/creditcard'] = [
                                          Ledgit::Handler::CreditCard,
                                          Ledgit::Handler::DKB::CreditCard
                                         ]
