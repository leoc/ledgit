# -*- coding: utf-8 -*-
require "csv"

class Ledgit
  module Handler
    class DKB
      include Ledgit::Handler::ClassMethods

      def initialize hash
        @agent = Mechanize.new
        @properties = hash
      end

      def login username, password
        # log into the online banking website
        @agent.get "https://banking.dkb.de:443/dkb/-?$javascript=disabled"
        form = @agent.page.forms.first
        form.j_username = prop[:username]
        form.j_password = prop[:password]
        form.submit

        # go to the transaction listing for the correct account type
        @agent.page.link_with(text: "Umsätze").click
        if prop[:account_type] == "giro"
          @agent.page.link_with(text: "Kontoumsätze\n\t\t\t")
        elsif prop[:account_type] == "creditcard"
          @agent.page.link_with(text: "Kreditkartenumsätze\n\t\t\t")
        end
      end

      ##
      # download the transaction data for the specified bank account
      # for the given timespan (fromTransactionDate,
      # toTransactionDate)
      def download_data from_date, to_date
        transactionDate = from_date.strftime('%d.%m.%Y')
        toTransactionDate = to_date.strftime('%d.%m.%Y')

        form = @agent.page.forms[1]

        form.field_with(:name => 'slBankAccount').
          option_with(:text => /#{prop[:account_cardnumber]}/).select
        form.radiobutton_with(value: "1").check
        form.field_with(name: "transactionDate").value = transactionDate
        form.field_with(name: "toTransactionDate").value = toTransactionDate
        form.submit

        @agent.page.link_with(text: "CSV-Export").click
        @agent.page.body
      end

      ##
      # parses the raw data from the DKB website into a hash that
      # ledge_it can work with.
      def parse_data data
        data.encode! "UTF-8", "ISO-8859-1"
        data.gsub!(/\A.*\n\n.*\n\n/m, "")

        result = CSV.parse(data, col_sep: ';', headers: :first_row)
        result.map do |row|
          {
            booking_date: Date.parse(row["Buchungstag"]),
            payment_date:  Date.parse(row["Wertstellung"]),
            partner:  row["Auftraggeber/Begünstigter"],
            text:  row["Buchungstext"],
            description:  row["Verwendungszweck"],
            account_number:  row["Kontonummer"],
            bank_code: row["BLZ"],
            amount: row["Betrag (EUR)"].gsub('.','').gsub(',','.').to_f
          }
        end
      end

    end
  end
end

Ledgit::Handler.list["dkb"] = Ledgit::Handler::DKB
