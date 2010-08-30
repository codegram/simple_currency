require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "SimpleCurrency" do

  def mock_uri(from_currency, to_currency, amount, result)
    args = [from_currency, to_currency, amount]
    response = "{\"result\":{\"value\":#{result},\"target\":\"#{to_currency}\",\"base\":\"#{from_currency}\"},\"status\":\"ok\"}"
    FakeWeb.register_uri(:get, "http://xurrency.com/api/#{args.join('/')}", :body => response)
  end

  it "enhances instances of Numeric with currency methods" do
    expect { 30.eur && 30.usd && 30.gbp }.to_not raise_error
  end

  it "returns a converted amount from one currency to another" do
    mock_uri('eur', 'usd', 2, 1.542)
    2.eur.to_usd.should == 1.54

    mock_uri('gbp', 'chf', 2, 3.4874)
    2.gbp.to_chf.should == 3.49
  end

  it "caches methods for faster reuse" do
    mock_uri('usd', 'eur', 1, 1.5)

    1.usd.to_eur.should == 1.5

    8.should respond_to(:usd)
    8.should respond_to(:to_eur)
  end

  context "when Rails is present" do

    before(:all) do
      require 'rails'
    end

    it "caches the exchange rate" do

      Rails.stub_chain("cache.write").and_return(true)
      Rails.stub_chain("cache.read").and_return(1.5)

      mock_uri('usd', 'eur', 1, 1.5)
      1.usd.to_eur.should == 1.5

      URI.should_not_receive(:parse)
      2.usd.to_eur.should == 3
    end

    it "ensures the cache is valid only for today" do
      now = Time.parse('2010-08-30')

      Rails.stub_chain("cache.write").and_return(true)
      Rails.stub_chain("cache.read").with('usd_eur_30-8-2010').and_return(1.5)

      mock_uri('usd', 'eur', 1, 1.5)
      1.usd.to_eur.should == 1.5

      Time.stub(:now).and_return(now + 86400) # Tomorrow
      Rails.stub_chain("cache.read").with('usd_eur_31-8-2010').and_return(nil)

      # Exchange rate has changed next day, so forget cache rate!
      mock_uri('usd', 'eur', 2, 4)
      2.usd.to_eur.should == 4

    end

  end

end
