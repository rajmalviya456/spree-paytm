# spree_paytm
Paytm payment gateway integration for spree

## Installation

1. Add this extension to your Gemfile with this line:

        gem 'spree_paytm', github: 'parassaini/spree-paytm'

2. Install the gem using Bundler:

        bundle install

3. Add migrations from extension:

        rails g spree_paytm:install

4. Restart your server

5. Add new payment method with provider

        Spree::Gateway::Paytm

6. Set all credentials from your paytm sandbox account.
