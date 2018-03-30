# coding: utf-8
require 'mechanize'

class Ledgit
  class Extension
    class ExtractAmazonOrderInfo
      attr_reader(:config, :amazon_email, :amazon_password, :cookiejar_path)

      def initialize(config)
        @config = config
        @amazon_email = config.fetch('email')
        @amazon_password = config.fetch('password')
        @cookiejar_path = config['cookiejar_path'] || '/tmp/ledgit_mechanize_cookiejar'

        create_mechanize_agent
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

      def create_mechanize_agent
        @agent = Mechanize.new
        @agent.cookie_jar.clear!
        @agent.user_agent_alias = 'Linux Mozilla'
        @agent.follow_meta_refresh = true
        @agent.redirect_ok = true

        return unless File.exist?(cookiejar_path)

        File.open(cookiejar_path, 'r') do |file|
          @agent.cookie_jar.load(file)
        end
      end

      def login_if_necessary
        form = @agent.page.form_with(name: 'signIn')
        return unless form
        puts "Logging into amazon ..."
        form.email = amazon_email
        form.password = amazon_password
        form.submit

        puts "Saving cookiejar to file #{cookiejar_path} ..."
        File.open(cookiejar_path, 'w') do |file|
          @agent.cookie_jar.save(file)
        end
      end

      def search_order(order_id)
        puts "Searching order ..."
        @agent.get('https://www.amazon.de/gp/css/order-history/ref=nav_youraccount_orders')

        login_if_necessary

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
