require 'ledgit/paypal'

class Ledgit
  class Handler
    class Paypal < Ledgit::Handler
      def paypal
        @paypal ||= Ledgit::PayPal.new(account.credentials)
      end

      def starts_at
        file.last_update_at
      end

      def get_transactions
        paypal
          .retrieve_transactions(starts_at)
          .reverse
          .map(&method(:map_paypal_transaction))
      end

      def map_paypal_transaction(transaction)
        {
          id: transaction[:transaction_id],
          payee: transaction[:name],
          booking_date: Date.parse(transaction[:timestamp]),
          payment_date: Date.parse(transaction[:timestamp]),
          tags: transaction_tags(transaction),
          postings: [
            receiving_posting(transaction),
            sending_posting(transaction)
          ]
        }
      end

      def transaction_tags(transaction)
        tags = {}
        tags[:paypal_email] = transaction[:email] if transaction[:email]
        tags[:paypal_name] = transaction[:name] if transaction[:name]
        tags[:timestamp] = transaction[:timestamp] if transaction[:timestamp]
        tags[:note] = transaction[:note] if transaction[:note]
        tags[:payment_status] = transaction[:payment_status] if transaction[:payment_status]
        tags[:transaction_type] = transaction[:transaction_type] if transaction[:transaction_type]
        tags[:payment_type] = transaction[:payment_type] if transaction[:payment_type]
        tags[:type] = transaction[:type] if transaction[:type]
        tags
      end

      def norm(amount)
        return if amount.nil?
        amount.gsub(/^-/, '')
      end

      def receiving_posting(transaction)
        {
          account: receiving_account(transaction),
          amount: norm(transaction[:amount]),
          currency: transaction[:currency],
          converted_amount: norm(transaction[:converted_amount]),
          converted_currency: transaction[:converted_currency],
          transfer: :in
        }
      end

      def receiving_account(transaction)
        if transaction[:amount][0] == '-'
          @classifier.classify(
            tags: transaction_tags(transaction),
            transfer: :out
          ) || 'Expenses:Unknown'
        else
          account.name
        end
      end

      def sending_posting(transaction)
        {
          account: sending_account(transaction),
          amount: norm(transaction[:amount]),
          currency: transaction[:currency],
          converted_amount: norm(transaction[:converted_amount]),
          converted_currency: transaction[:converted_currency],
          transfer: :out
        }
      end

      def sending_account(transaction)
        if transaction[:amount][0] == '-'
          account.name
        else
          @classifier.classify(
            tags: transaction_tags(transaction),
            transfer: :in
          ) || 'Income:Unknown'
        end
      end
    end
  end
end
