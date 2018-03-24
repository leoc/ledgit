# coding: utf-8
require 'mechanize'

class Ledgit
  class Extension
    class ExtractAmazonOrderInfo
      attr_reader(:config, :amazon_email, :amazon_password)

      def initialize(config)
        @config = config
        @amazon_email = config.fetch('email')
        @amazon_password = config.fetch('password')

        login_browser_session
      end

      def apply(transaction)
        order_id = nil
        transaction[:tags].values.each do |value|
          match = value.match(/(?<orderid>\d{3}\-\d{7}\-\d{7}) Amazon/)
          if match
            order_id = match[:orderid]
            break
          end
        end

        return transaction if order_id.nil?

        products = search_order(order_id)

        return transaction if products.empty?
        transaction[:postings].first[:comments] = products.map { |p| "#{p[:category]}: #{p[:name]}" }

        transaction
      end

      private

      def login_browser_session
        @agent = Mechanize.new
        @agent.cookie_jar.clear!
        @agent.user_agent_alias = 'Linux Mozilla'
        @agent.follow_meta_refresh = true
        @agent.redirect_ok = true

        @agent.get('https://www.amazon.de/gp/css/order-history/ref=nav_youraccount_orders')

        form = @agent.page.form_with(name: 'signIn')
        form.email = amazon_email
        form.password = amazon_password
        form.submit
      end

      def search_order(order_id)
        @agent.get('https://www.amazon.de/gp/css/order-history/ref=nav_youraccount_orders')
        form = @agent.page.form_with(action: '/gp/your-account/order-history/ref=oh_aui_search')
        form.search = order_id
        form.submit
        @agent.page.link_with(text: /Bestelldetails/).click
        urls = @agent.page.css('div.a-box.shipment a.a-link-normal')
                 .map { |link| link.attr('href') }
                 .delete_if { |url| url !~ /\/gp\/product/ }
                 .uniq
        urls.map do |url|
          @agent.get(url)
          {
            name: @agent.page.css('#productTitle').text.strip,
            category: @agent.page.css('.nav-a-content').first.text,
            category_id: @agent.page.css('#nav-subnav').attr('data-category').value
          }
        end
      end
    end
  end
end

Ledgit.extensions['extract_amazon_order_info'] = Ledgit::Extension::ExtractAmazonOrderInfo
