begin
  require 'simplecov'; 
  SimpleCov.start do
    add_group "Lib", 'lib'
  end
rescue LoadError
end

begin; require 'turn'; rescue LoadError; end

require 'fakeweb'
require 'simple_currency'
require 'minitest/spec'
require 'minitest/mock'
require 'minitest/autorun'

def fixture(name)
  File.read(File.dirname(__FILE__) +  "/support/#{name}")
end

def mock_xavier_api(date, options = {})
  date = date.send(:to_date)
  args = [date.year, date.month.to_s.rjust(2, '0'), date.day.to_s.rjust(2,'0')]

  response = {:body => fixture("xavier.xml")}
  response = {:body => "No exchange rate available", :status => ["404", "Not Found"]} if options[:fail]

  url = "http://api.finance.xaviermedia.com/api/#{args.join('/')}.xml"
  FakeWeb.register_uri(:get, url, response)
end
