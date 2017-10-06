require "paypal_nvp"
require 'date'

class Ledgit
  class PayPal
    attr_reader(:username, :password, :certificate, :url)

    def initialize(credentials)
      @username = credentials.fetch('username')
      @password = credentials.fetch('password')
      @certificate = credentials.fetch('certificate')
      @url = credentials.fetch('url')
    end

    def gateway
      @gateway ||= PaypalNVP.new(
        false,
        user: username,
        pass: password,
        cert: certificate,
        url: url,
        open_timeout: 3,
        read_timeout: 60
      )
    end

    def retrieve_transactions(starts_at, ends_at = DateTime.now)
      transactions = api_get_all_transactions(
        starts_at.strftime("%Y-%m-%dZ00:00:00"),
        ends_at.strftime("%Y-%m-%dZ00:00:00")
      )
      merge_currency_conversions(transactions)
    end

    private

    def merge_currency_conversions(transactions)
      merged = []
      transactions.each do |transaction|
        case transaction[:type]
        when 'Currency Conversion (credit)'
        when 'Currency Conversion (debit)'
          merged.last.tap do |last|
            last[:converted_amount] = transaction[:amount]
            last[:converted_net_amount] = transaction[:net_amount]
            last[:converted_fee_amount] = transaction[:fee_amount]
            last[:converted_currency] = transaction[:currency]
          end
        else
          merged.push(transaction)
        end
      end
      merged
    end

    def api_extract_transactions(result)
      timestamps = result.select { |key| key =~ /^L_TIMESTAMP/ }.values
      timestamps.each_with_index.map do |timestamp, i|
        {
          timestamp: timestamp,
          timezone: result["L_TIMEZONE#{i}"],
          type: result["L_TYPE#{i}"],
          email: result["L_EMAIL#{i}"],
          name: result["L_NAME#{i}"],
          transaction_id: result["L_TRANSACTIONID#{i}"],
          status: result["L_STATUS#{i}"],
          amount: result["L_AMT#{i}"],
          currency: result["L_CURRENCYCODE#{i}"],
          fee_amount: result["L_FEEAMT#{i}"],
          net_amount: result["L_NETAMT#{i}"],
        }
      end
    end

    def api_get_transactions(startdate, enddate)
      puts "Fetching transactions from #{startdate} to #{enddate}"
      data = {
        method: 'TransactionSearch',
        startdate: startdate,
        enddate: enddate
      }
      gateway.call_paypal(data)
    end

    def api_get_all_transactions(startdate, enddate)
      result = api_get_transactions(startdate, enddate)
      transactions = api_extract_transactions(result)
      while result['L_ERRORCODE0'] == '11002'
        result = api_get_transactions(startdate, transactions.last[:timestamp])
        transactions.pop
        transactions.push(*api_extract_transactions(result))
      end
      transactions
    end
  end
end
