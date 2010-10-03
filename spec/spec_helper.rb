$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'fakeweb'

require 'simple_currency'
require 'rspec'
# require 'rspec/autorun'   => require it back in beta.23

module HelperMethods
  def fixture(name)
    File.read(File.dirname(__FILE__) +  "/support/#{name}")
  end

  def mock_xurrency_api(from_currency, to_currency, amount, result, options = {})
    args = [from_currency, to_currency, amount]

    response = "{\"result\":{\"value\":#{result},\"target\":\"#{to_currency}\",\"base\":\"#{from_currency}\"},\"status\":\"ok\"}"

    response = "{\"message\":\"#{options[:fail_with]}\", \"status\":\"fail\"\}" if options[:fail_with]

    FakeWeb.register_uri(:get, "http://xurrency.com/api/#{args.join('/')}", :body => response)
  end

  def mock_xavier_api(date, options = {})
    date = date.send(:to_date)
    args = [date.year, date.month.to_s.rjust(2, '0'), date.day.to_s.rjust(2,'0')]

    response = {:body => fixture("xavier.xml")}
    response = {:body => "No exchange rate available", :status => ["404", "Not Found"]} if options[:fail]

    FakeWeb.register_uri(:get, "http://api.finance.xaviermedia.com/api/#{args.join('/')}.xml", response)
  end

end

RSpec.configuration.include(HelperMethods)
