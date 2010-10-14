$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'

require 'simplecov'
SimpleCov.start do
  add_group "Lib", 'lib'
end
require 'fakeweb'

require 'simple_currency'
require 'rspec'
# require 'rspec/autorun'   => require it back in beta.23

module HelperMethods
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

    if t = options[:timeout]
      uri = double('uri')
      uri_open = double('uri.open')
      URI.stub(:parse).with(url).and_return(uri)
      uri.stub(:open).and_return(uri_open)
      t.times { uri_open.should_receive(:read).once.ordered.and_raise(Timeout::Error) }
      uri_open.should_receive(:read).once.ordered.and_return(response[:body])
    end
  end

end

RSpec.configuration.include(HelperMethods)
