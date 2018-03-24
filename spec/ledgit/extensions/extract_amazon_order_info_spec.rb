describe Ledgit::Extension::ExtractAmazonOrderInfo do
  describe '#apply' do
    describe 'matching an amazon id' do
      before(:each) do
        expect_any_instance_of(Ledgit::Extension::ExtractAmazonOrderInfo)
          .to receive(:login_browser_session)
                .and_return(nil)
        expect_any_instance_of(Ledgit::Extension::ExtractAmazonOrderInfo)
          .to receive(:search_order)
                .with('028-8269844-9593154')
                .and_return(
                  [
                    {
                      name: 'Test Product',
                      category: 'Some Nice Category'
                    }
                  ]
                )
      end
      let(:transaction1) do
        {
          booking_date: Date.new(2017, 6, 1),
          tags: {
            description: '028-8269844-9593154 Amazon .Mktplce EU-DE 9729152308661449'
          },
          postings: [
            {
              account: 'Expenses:Entertainment:Movie',
              amount: '9.99',
              currency: 'EUR',
              transfer: :in
            }, {
              account: 'Expenses:Entertainment:Movie',
              amount: '9.99',
              currency: 'EUR',
              transfer: :out
            }
          ]
        }
      end
      let(:config) do
        {
          'email' => 'some@mail.com',
          'password' => 'somesecret'
        }
      end
      let(:extension) do
        Ledgit::Extension::ExtractAmazonOrderInfo.new(
          'email' => 'some@mail.com',
          'password' => 'somesecret'
        )
      end

      it 'adds product information to the credit account' do
        expect(extension.apply(transaction1)[:postings].first)
          .to include(comments: ['Some Nice Category: Test Product'])
      end
    end

    describe 'not matching an amazon id' do
      before(:each) do
        expect_any_instance_of(Ledgit::Extension::ExtractAmazonOrderInfo)
          .to receive(:login_browser_session)
                .and_return(nil)
        expect_any_instance_of(Ledgit::Extension::ExtractAmazonOrderInfo)
          .to receive(:search_order)
                .with('028-8269844-9593154')
                .and_return(
                  [
                    {
                      name: 'Test Product',
                      category: 'Some Nice Category'
                    }
                  ]
                )
      end
      let(:transaction1) do
        {
          booking_date: Date.new(2017, 6, 1),
          tags: {
            description: '028-8269844-9593154 Amazon .Mktplce EU-DE 9729152308661449'
          },
          postings: [
            {
              account: 'Expenses:Entertainment:Movie',
              amount: '9.99',
              currency: 'EUR',
              transfer: :in
            }, {
              account: 'Expenses:Entertainment:Movie',
              amount: '9.99',
              currency: 'EUR',
              transfer: :out
            }
          ]
        }
      end
      let(:config) do
        {
          'email' => 'some@mail.com',
          'password' => 'somesecret'
        }
      end
      let(:extension) do
        Ledgit::Extension::ExtractAmazonOrderInfo.new(
          'email' => 'some@mail.com',
          'password' => 'somesecret'
        )
      end

      it 'adds product information to the credit account' do
        expect(extension.apply(transaction1)).to eq(transaction1)
      end
    end
  end
end
