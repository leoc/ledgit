require 'json'

describe Ledgit::PayPal do
  describe '#merge_currency_conversions' do
    let(:transactions) do
      [
        {
          type: "Transfer",
          name: "Bank Account (direct debit)",
          amount: "19.95",
          timestamp: "2016-12-16T18:01:39Z",
          fee_amount: "0.00",
          transaction_id: "0",
          net_amount: "19.95",
          email: nil,
          currency: "EUR",
          timezone: "GMT",
          status: "Completed"
        },
        {
          status: "Completed",
          timezone: "GMT",
          currency: "EUR",
          email: "someshop@world.com",
          net_amount: "-47.16",
          fee_amount: "0.00",
          transaction_id: "1",
          amount: "-47.16",
          timestamp: "2016-12-16T07:03:32Z",
          type: "Payment",
          name: "Some Shop"
        },
        {
          status: "Completed",
          email: nil,
          currency: "EUR",
          timezone: "GMT",
          fee_amount: "0.00",
          transaction_id: "2",
          net_amount: "47.16",
          type: "Transfer",
          name: "Bank Account (direct debit)",
          amount: "47.16",
          timestamp: "2016-12-16T07:03:32Z"
        },
        {
          type: "Currency Conversion (credit)",
          name: "From Euro",
          amount: "73.99",
          timestamp: "2016-12-15T08:33:09Z",
          fee_amount: "0.00",
          transaction_id: "3",
          net_amount: "73.99",
          email: nil,
          timezone: "GMT",
          currency: "USD",
          status: "Completed"
        },
        {
          net_amount: "-71.66",
          transaction_id: "4",
          fee_amount: "0.00",
          timestamp: "2016-12-15T08:33:09Z",
          amount: "-71.66",
          name: "To U.S. Dollar",
          type: "Currency Conversion (debit)",
          status: "Completed",
          currency: "EUR",
          timezone: "GMT",
          email: nil
        },
        {
          net_amount: "71.66",
          fee_amount: "0.00",
          transaction_id: "5",
          amount: "71.66",
          timestamp: "2016-12-15T08:33:09Z",
          type: "Transfer",
          name: "Bank Account (direct debit)",
          status: "Completed",
          currency: "EUR",
          timezone: "GMT",
          email: nil
        },
        {
          name: "Other Shop",
          type: "Payment",
          timestamp: "2016-12-15T08:33:09Z",
          amount: "-73.99",
          transaction_id: "6",
          fee_amount: "0.00",
          net_amount: "-73.99",
          email: "othershop@world.com",
          timezone: "GMT",
          currency: "USD",
          status: "Completed"
        },
        {
          email: "othershop@world.com",
          currency: "USD",
          timezone: "GMT",
          status: "Completed",
          type: "Authorization",
          name: "Other Shop",
          amount: "-73.99",
          timestamp: "2016-12-15T08:33:02Z",
          fee_amount: "0.00",
          transaction_id: "7",
          net_amount: "-73.99"
        },
        {
          net_amount: "-9.99",
          transaction_id: "8",
          fee_amount: "0.00",
          timestamp: "2016-12-04T16:45:26Z",
          amount: "-9.99",
          name: "What an online shop",
          type: "Payment",
          status: "Completed",
          currency: "USD",
          timezone: "GMT",
          email: "onlineshop@world.com"
        },
        {
          status: "Completed",
          email: nil,
          timezone: "GMT",
          currency: "USD",
          fee_amount: "0.00",
          transaction_id: "9",
          net_amount: "9.99",
          type: "Currency Conversion (credit)",
          name: "From Euro",
          amount: "9.99",
          timestamp: "2016-12-04T16:45:26Z"
        },
        {
          timezone: "GMT",
          currency: "EUR",
          email: nil,
          status: "Completed",
          timestamp: "2016-12-04T16:45:26Z",
          amount: "-9.67",
          name: "To U.S. Dollar",
          type: "Currency Conversion (debit)",
          net_amount: "-9.67",
          transaction_id: "10",
          fee_amount: "0.00"
        },
        {
          fee_amount: "0.00",
          transaction_id: "11",
          net_amount: "9.67",
          type: "Transfer",
          name: "Credit Card",
          amount: "9.67",
          timestamp: "2016-12-04T16:45:26Z",
          status: "Completed",
          email: nil,
          currency: "EUR",
          timezone: "GMT"
        }
      ]
    end

    let(:ledgit) do
      Ledgit::PayPal.new(
        'username' => '',
        'password' => '',
        'certificate' => '',
        'url' => ''
      )
    end

    it 'merges currency conversion transactions regardless of transaction order' do
      merged_transactions = ledgit.send(:merge_currency_conversions, transactions)
      expect(merged_transactions.count).to eq(8)
      expect(merged_transactions)
        .to include(
              type: "Transfer",
              name: "Bank Account (direct debit)",
              amount: "19.95",
              timestamp: "2016-12-16T18:01:39Z",
              fee_amount: "0.00",
              transaction_id: "0",
              net_amount: "19.95",
              email: nil,
              currency: "EUR",
              timezone: "GMT",
              status: "Completed"
            )
      expect(merged_transactions)
        .to include(
              status: "Completed",
              timezone: "GMT",
              currency: "EUR",
              email: "someshop@world.com",
              net_amount: "-47.16",
              fee_amount: "0.00",
              transaction_id: "1",
              amount: "-47.16",
              timestamp: "2016-12-16T07:03:32Z",
              type: "Payment",
              name: "Some Shop"
            )
      expect(merged_transactions)
        .to include(
              status: "Completed",
              email: nil,
              currency: "EUR",
              timezone: "GMT",
              fee_amount: "0.00",
              transaction_id: "2",
              net_amount: "47.16",
              type: "Transfer",
              name: "Bank Account (direct debit)",
              amount: "47.16",
              timestamp: "2016-12-16T07:03:32Z"
            )
      expect(merged_transactions)
        .to include(
              name: "Other Shop",
              type: "Payment",
              timestamp: "2016-12-15T08:33:09Z",
              amount: "-73.99",
              transaction_id: "6",
              fee_amount: "0.00",
              net_amount: "-73.99",
              email: "othershop@world.com",
              timezone: "GMT",
              currency: "USD",
              status: "Completed",
              converted_amount: "-71.66",
              converted_net_amount: "-71.66",
              converted_fee_amount: "0.00",
              converted_currency: "EUR"
            )
      expect(merged_transactions)
        .to include(
              email: "othershop@world.com",
              currency: "USD",
              timezone: "GMT",
              status: "Completed",
              type: "Authorization",
              name: "Other Shop",
              amount: "-73.99",
              timestamp: "2016-12-15T08:33:02Z",
              fee_amount: "0.00",
              transaction_id: "7",
              net_amount: "-73.99"
            )
      expect(merged_transactions)
        .to include(
              net_amount: "-9.99",
              transaction_id: "8",
              fee_amount: "0.00",
              timestamp: "2016-12-04T16:45:26Z",
              amount: "-9.99",
              name: "What an online shop",
              type: "Payment",
              status: "Completed",
              currency: "USD",
              timezone: "GMT",
              email: "onlineshop@world.com",
              converted_amount: "-9.67",
              converted_net_amount: "-9.67",
              converted_fee_amount: "0.00",
              converted_currency: "EUR"
            )
      expect(merged_transactions)
        .to include(
              fee_amount: "0.00",
              transaction_id: "11",
              net_amount: "9.67",
              type: "Transfer",
              name: "Credit Card",
              amount: "9.67",
              timestamp: "2016-12-04T16:45:26Z",
              status: "Completed",
              email: nil,
              currency: "EUR",
              timezone: "GMT"
            )
    end
  end
end
