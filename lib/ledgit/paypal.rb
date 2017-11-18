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
      transactions = merge_currency_conversions(transactions)
      transactions_with_transaction_details(transactions)
    end

    private

    def transactions_with_transaction_details(transactions)
      count = transactions.length
      transactions.each_with_index.map do |transaction, i|
        puts "Fetching transaction details for #{transaction[:transaction_id]} (#{i+1} / #{count})"
        details = api_get_transaction_details(transaction[:transaction_id])
        transaction[:note] = details['NOTE'] if details['NOTE']
        transaction[:payment_type] = details['PAYMENTTYPE'] if details['PAYMENTTYPE']
        transaction[:transaction_type] = details['TRANSACTIONTYPE'] if details['TRANSACTIONTYPE']
        transaction[:payment_status] = details['PAYMENTSTATUS'] if details['PAYMENTSTATUS']
        transaction
      end
    end

    def merge_currency_conversions(transactions)
      groups = transactions.group_by { |t| t[:timestamp] }
      groups.values.flat_map do |group_transactions|
        grouped_types = group_transactions.group_by { |t| t[:type] }
        grouped_types.delete('Currency Conversion (credit)')
        debit = grouped_types.delete('Currency Conversion (debit)')&.first
        if debit
          grouped_types['Payment'].first[:converted_amount] = debit[:amount]
          grouped_types['Payment'].first[:converted_net_amount] = debit[:net_amount]
          grouped_types['Payment'].first[:converted_fee_amount] = debit[:fee_amount]
          grouped_types['Payment'].first[:converted_currency] = debit[:currency]
        end
        grouped_types.values.flatten
      end
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

    def api_get_transaction_details(transaction_id)
      data = {
        method: "GetTransactionDetails",
        transactionid: transaction_id
      }
      gateway.call_paypal(data)
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
