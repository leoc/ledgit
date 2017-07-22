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
          form = @agent.page.forms[1]

          form.field_with(name: 'j_username').value = username
          form.field_with(name: 'j_password').value = password

          button = form.button_with(type: 'submit')

          @agent.submit(form, button)

          # go to the transaction listing for the correct account type
          @agent.page.link_with(text: /Umsätze/).click
        end

        ##
        # download the transaction data for the specified bank account
        # for the given timespan (fromTransactionDate,
        # toTransactionDate)
        def download_data
          form = @agent.page.forms[2]

          transaction_date = (last_update_at - 5).strftime('%d.%m.%Y')
          to_transaction_date = Date.today.strftime('%d.%m.%Y')

          safe_cardnumber = cardnumber.dup
          safe_cardnumber[4...12] = '*' * 8

          form.field_with(name: /slAllAccounts/).option_with(text: /#{Regexp.escape(safe_cardnumber)}/).select

          form.submit

          form = @agent.page.forms[2]

          form.radiobuttons[1].check

          form.field_with(name: /postingDate/).value = transaction_date
          form.field_with(name: /toPostingDate/).value = to_transaction_date

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
            if row['Belegdatum'].empty? || row['Wertstellung'].empty?
              nil
            else
              {
                booking_date: Date.parse(row['Belegdatum']),
                payment_date: Date.parse(row['Wertstellung']),
                description:  row['Beschreibung'],
                amount: row['Betrag (EUR)'].gsub('.', '').gsub(',', '.').to_f
              }
            end
          end.compact.reverse
        end
      end
    end
  end
end

Ledgit::Handler.list['dkb/creditcard'] = [
                                          Ledgit::Handler::CreditCard,
                                          Ledgit::Handler::DKB::CreditCard
                                         ]
