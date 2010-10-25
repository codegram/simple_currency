#simple_currency

A really simple currency converter using XavierMedia API.
Compatible with Ruby 1.8, 1.9, JRuby 1.5.3 and Rubinius 1.1.

##Notes

Since version 1.2, simple_currency no longer uses Xurrency API in its
background, due to restrictions on the number of daily requests. If you
would like to use it, please use the [fork by Alfonso
Jiménez](http://github.com/alfonsojimenez/simple_xurrency), author and
maintainer of xurrency.com service.

##Usage

Just require it and all your numeric stuff gets this fancy DSL for free:

    30.eur.to_usd
    # => 38.08

    150.eur.to_usd
    # => 190.4
    239.usd.to_eur
    # => 187.98 
    # These don't even hit the Internets!
    # (They take advantage of Rails cache)

    70.usd.to_chf
    # => 71.9

But what if you want to do the currency exchange according to a specific date
in the past? Just do this:

    # You can use any time or date object
    42.eur.at(1.year.ago).to_usd
    # => 60.12
    42.eur.at(Time.parse('2009-09-01')).to_usd
    # => 60.12

You can also add an subtract money expressions, which will return a result
converted to the former currency of the expression:

    42.eur + 30.usd
    # => The same as adding 42 and 30.usd.to_eur

    10.gbp + 1.eur
    # => The same as adding 10 and 1.eur.to_gbp

##Installation

###Rails 3

In your Gemfile:

  gem "simple_currency"

###Not using Rails?

Then you have to manually install the gem:

    gem install simple_currency

And manually require it as well:

    require "simple_currency"

##Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add specs for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  If you want to have your own version, that is fine but bump version
  in a commit by itself I can ignore when I pull.
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Codegram. See LICENSE for details.
