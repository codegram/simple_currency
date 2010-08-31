require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "SimpleCurrency" do

  describe "in its basic behavior" do

    it "enhances instances of Numeric with currency methods" do
      expect { 30.eur && 30.usd && 30.gbp }.to_not raise_error
    end

    it "handles zero values (by returning them straight away)" do
      0.usd.to_eur.should == 0.0 
    end

  end

  context "using Xurrency API for right-now exchange" do

    it "returns a converted amount from one currency to another" do
      mock_xurrency_api('eur', 'usd', 2, 1.542)
      2.eur.to_usd.should == 1.54

      mock_xurrency_api('gbp', 'chf', 2, 3.4874)
      2.gbp.to_chf.should == 3.49
    end

    it "caches methods for faster reuse" do
      mock_xurrency_api('usd', 'eur', 1, 1.5)

      1.usd.to_eur.should == 1.5

      8.should respond_to(:usd)
      8.should respond_to(:to_eur)
    end

    it "raises any error returned by the api call" do
      mock_xurrency_api('usd', 'xxx', 1, 1.5, :fail_with => "The currencies are not valid")
      mock_xurrency_api('usd', 'eur', 1_000_000_000, 1.5, :fail_with => "The amount should be between 0 and 999999999")

      expect {1.usd.to_xxx}.to raise_error("The currencies are not valid")
      expect {1_000_000_000.usd.to_eur}.to raise_error("The amount should be between 0 and 999999999")
    end

    it "handles a negative value returning a negative as well" do
      mock_xurrency_api('usd', 'eur', 1, 1.5)

      -1.usd.to_eur.should == -1.5
    end

  end

  context "using XavierMedia API for exchange with historical date" do

    let(:the_past) { Time.parse('2010-08-25')}
    let(:the_ancient_past) { Time.parse('1964-08-25')}

    it "enhances instances of Numeric with :at method" do
      expect { 30.eur.at(Time.now) }.to_not raise_error
      expect { 30.usd.at("no date")}.to raise_error("Must use 'at' with a time or date object")
      expect { 30.gbp.at(:whatever_arg) }.to raise_error("Must use 'at' with a time or date object")
    end

    it "returns a converted amount from one currency to another" do
      mock_xavier_api(the_past)
      2.eur.at(the_past).to_usd.should == 2.54
      2.usd.at(the_past).to_eur.should == 1.58
      2.gbp.at(the_past).to_usd.should == 3.07
    end

    it "raises an error when no data available" do
      mock_xavier_api(the_past, :fail => true)  # Currency does not exist!
      mock_xavier_api(the_ancient_past, :fail => true) # Too old!

      expect {1.usd.at(the_past).to_xxx}.to raise_error(OpenURI::HTTPError)
      expect {1.usd.at(the_ancient_past).to_eur}.to raise_error(OpenURI::HTTPError)
    end

  end

  context "when Rails (and its cache goodness) is present" do

    let(:now) { Time.parse('2010-08-30') }

    before(:all) do
      require 'rails'
    end

    context "using Xurrency API for right-now exchange" do

      before(:each) do
        Time.stub(:now).and_return(now)

        Rails.stub_chain("cache.read").and_return(false)
        Rails.stub_chain("cache.write").and_return(true)
      end

      it "reads the exchange rate from the cache" do
        Rails.stub_chain("cache.read").and_return(1.5)

        mock_xurrency_api('usd', 'eur', 1, 1.5)
        1.usd.to_eur.should == 1.5

        URI.should_not_receive(:parse)
        2.usd.to_eur.should == 3
      end

      it "reads the inverse exchange rate from the cache" do
        Rails.stub_chain("cache.read").with('usd_eur_30-8-2010').and_return(1.5)
        Rails.stub_chain("cache.read").with('gbp_eur_30-8-2010').and_return(3)
        Rails.stub_chain("cache.read").with('gbp_usd_30-8-2010').and_return(false)

        mock_xurrency_api('usd', 'eur', 1, 1.5)
        mock_xurrency_api('gbp', 'eur', 1, 3)

        1.usd.to_eur.should == 1.5
        1.gbp.to_eur.should == 3

        URI.should_not_receive(:parse)
        3.eur.to_usd.should == 2
        3.eur.to_gbp.should == 1
      end

      it "caches the exchange rate" do
        Rails.stub_chain("cache.read").with('usd_eur_30-8-2010').and_return(false)

        Rails.cache.should_receive(:write).with('usd_eur_30-8-2010', 1.5)

        mock_xurrency_api('usd', 'eur', 1, 1.5)
        1.usd.to_eur.should == 1.5
      end

      it "ensures the cache is valid only for today" do
        Rails.stub_chain("cache.read").with('usd_eur_30-8-2010').and_return(1.5)

        mock_xurrency_api('usd', 'eur', 1, 1.5)
        1.usd.to_eur.should == 1.5

        Time.stub(:now).and_return(now + 86400) # One day later
        Rails.stub_chain("cache.read").with('usd_eur_31-8-2010').and_return(nil)

        # Exchange rate has changed next day, so forget cache rate!
        mock_xurrency_api('usd', 'eur', 2, 4)
        2.usd.to_eur.should == 4
      end

    end

    context "using XavierMedia API for exchange with historical date" do

      let(:the_past) { Time.parse('2010-08-25') }

      before(:each) do
        Rails.stub_chain("cache.read").and_return(false)
        Rails.stub_chain("cache.write").and_return(true)

        mock_xavier_api(the_past)
      end

      it "reads the exchange rate from the cache" do
        Rails.stub_chain("cache.read").with('usd_eur_25-8-2010').and_return(0.79)

        URI.should_not_receive(:parse)
        1.usd.at(the_past).to_eur.should == 0.79
        2.usd.at(the_past).to_eur.should == 1.58
      end

      it "caches the exchange rate with full precision" do
        Rails.cache.should_receive(:write).with('eur_jpy_25-8-2010', 107.07).ordered
        Rails.cache.should_receive(:write).with("eur_usd_25-8-2010", 1.268).ordered
        Rails.cache.should_receive(:write).with("eur_huf_25-8-2010", 287.679993).ordered

        1.eur.at(the_past).to_jpy
        1.eur.at(the_past).to_usd
        2.eur.at(the_past).to_huf
      end

      it "caches the XML response" do
        Rails.cache.should_receive(:write).with('xaviermedia_25-8-2010', an_instance_of(Array)).and_return(true)

        1.eur.at(the_past).to_usd
      end

      it "uses the base currency (EUR) cache to calculate other rates" do
        1.eur.at(the_past).to_jpy.should == 107.07

        Rails.stub_chain("cache.read").with('xaviermedia_25-8-2010').and_return(Crack::XML.parse(fixture('xavier.xml'))["xavierresponse"]["exchange_rates"]["fx"])

        URI.should_not_receive(:parse)

        1.usd.at(the_past).to_eur.should == 0.79
        1.eur.at(the_past).to_gbp.should == 0.82
        2.gbp.at(the_past).to_usd.should == 3.07
      end
    end
  end
end
