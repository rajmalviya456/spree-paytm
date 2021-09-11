# frozen_string_literal: true

module Spree
  module Gateway
    class Paytm < Gateway
      preference :merchant_id, :string
      preference :merchant_key, :string
      preference :website, :string
      preference :industry_type_id, :string
      preference :channel_id, :string

      PaytmRequestParams = %w[REQUEST_TYPE MID ORDER_ID CUST_ID TXN_AMOUNT CHANNEL_ID INDUSTRY_TYPE_ID
                              WEBSITE MOBILE_NO EMAIL MSISDN CALLBACK_URL THEME SUBS_SERVICE_ID SUBS_AMOUNT_TYPE SUBS_FREQUENCY SUBS_FREQUENCY_UNIT SUBS_ENABLE_RETRY SUBS_EXPIRY_DATE PAYMENT_MODE_ONLY AUTH_MODE PAYMENT_TYPE_ID CARD_TYPE BANK_CODE PROMO_CAMP_ID SUBS_MAX_AMOUNT SUBS_START_DATE SUBS_GRACE_DAYS SUBS_ID ORDERID REFUNDAMOUNT TXNTYPE REFID TXNID COMMENTS MERC_UNQ_REF].freeze

      def supports?(_source)
        true
      end

      def provider_class
        self
      end

      def provider
        self
      end

      def auto_capture?
        true
      end

      def method_type
        'paytm'
      end

      def purchase(_amount, _source, _gateway_options = {})
        ActiveMerchant::Billing::Response.new(true, 'paytm success')
      end

      def txnid(order)
        "#{order.id}-#{SecureRandom.random_number(100_000)}-#{order.number}"
      end

      def refund_url
        "https://#{domain}/oltp/HANDLER_INTERNAL/REFUND"
      end

      def status_query_url
        "https://#{domain}/oltp/HANDLER_INTERNAL/TXNSTATUS"
      end

      def txn_url
        "https://#{domain}/theia/processTransaction"
      end

      def request_type
        'DEFAULT' # or SUBSCRIBE
      end

      ### function returns a single encrypted value ###
      ### input data -> value to be encrypted ###
      ### key -> key to use for encryption ###
      def new_pg_encrypt_variable(data, key)
        # #aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
        aes = OpenSSL::Cipher.new('aes-128-cbc')
        aes.encrypt
        aes.key = key
        aes.iv = '@@@@&&&&####$$$$'
        encrypted_data = nil
        begin
          encrypted_data = aes.update(data.to_s) + aes.final
          encrypted_data = Base64.encode64(encrypted_data)
        rescue Exception => e
          return false
        end
        encrypted_data
      end

      ### function returns dictionary of decrypted data ###
      ### accepts a dictionary with data and key to decrypt with ###
      ### can accept multiple key value pairs in the dictionary ###
      def new_pg_decrypt(paytmparams)
        return false if (paytmparams.class != Hash) || (paytmparams.keys == [])
        return false unless paytmparams.key?(:key)

        decrypted_data = Hash[]
        key = paytmparams.delete(:key)
        keys = paytmparams.keys
        # #aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
        aes = OpenSSL::Cipher.new('aes-128-cbc')
        begin
          keys.each do |k|
            data = paytmparams[k]
            aes.decrypt
            aes.key = key
            aes.iv = '@@@@&&&&####$$$$'
            decrypted_k = Base64.decode64(k.to_s)
            decrypted_k = aes.update(decrypted_k.to_s) + aes.final
            if data.empty?
              decrypted_data[decrypted_k] = ''
              next
            end
            aes.decrypt
            aes.key = key
            aes.iv = '@@@@&&&&####$$$$'
            data = Base64.decode64(data)
            decrypted_data[decrypted_k] = aes.update(data) + aes.final
          end
        rescue Exception => e
          return false
        end
        decrypted_data
      end

      ### function returns a single decrypted value ###
      ### input data -> value to be decrypted ###
      ### key -> key to use for decryption ###
      def new_pg_decrypt_variable(data, key)
        # #aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc")
        aes = OpenSSL::Cipher.new('aes-128-cbc')
        aes.decrypt
        aes.key = key
        aes.iv = '@@@@&&&&####$$$$'
        decrypted_data = nil
        begin
          decrypted_data = Base64.decode64(data.to_s)
          decrypted_data = aes.update(decrypted_data) + aes.final
        rescue Exception => e
          return false
        end
        decrypted_data
      end

      def new_pg_generate_salt(length)
        salt = SecureRandom.urlsafe_base64(length * (3.0 / 4.0))
        salt.to_s
      end

      ### function returns checksum of given key value pairs ###
      ### accepts a hash with key value pairs ###
      ### calculates sha256 checksum of given values ###

      def new_pg_checksum(paytmparams, key = preferred_merchant_key, salt_length = 4)
        return false if paytmparams.class != Hash
        return false if key.empty?

        checkSumParamHash = {}
        keys = paytmparams.keys
        keys.each do |k|
          checkSumParamHash[k] = paytmparams[k] if PaytmRequestParams.include?(k)
        end
        salt = new_pg_generate_salt(salt_length)
        keys = checkSumParamHash.keys
        str = nil
        keys = keys.sort
        keys.each do |k|
          if str.nil?
            str = checkSumParamHash[k].to_s
            next
          end
          unless checkSumParamHash[k].to_s.include?('REFUND') || checkSumParamHash[k].to_s.include?('|')
            str = "#{str}|#{checkSumParamHash[k]}"
          end
        end
        str = "#{str}|#{salt}"
        check_sum = Digest::SHA256.hexdigest(str)
        check_sum += salt
        ### encrypting checksum ###
        new_pg_encrypt_variable(check_sum, key)
      end

      ### function returns checksum of given key value pairs ###
      ### accepts a hash with key value pairs ###
      ### calculates sha256 checksum of given values ###
      def new_pg_refund_checksum(paytmparams, key = preferred_merchant_key, salt_length = 4)
        keys = paytmparams.keys
        keys.each do |k|
          next if paytmparams[k].empty?
          # if params[k].to_s.include? "REFUND"
          next unless paytmparams[k].to_s.include? '|'

          paytmparams[k] = paytmparams[k]
        end
        return false if paytmparams.class != Hash
        return false if key.empty?

        salt = new_pg_generate_salt(salt_length)
        keys = paytmparams.keys
        str = nil
        keys = keys.sort
        keys.each do |k|
          if str.nil?
            str = paytmparams[k].to_s
            next
          end
          str = "#{str}|#{paytmparams[k]}"
        end
        str = "#{str}|#{salt}"
        check_sum = Digest::SHA256.hexdigest(str)
        check_sum += salt
        ### encrypting checksum ###
        new_pg_encrypt_variable(check_sum, key)
      end

      ### function returns checksum of given key value pairs (must contain the :checksum key) ###
      ### accepts a hash with key value pairs ###
      ### calculates sha256 checksum of given values ###
      ### returns true if checksum is consistent ###
      ### returns false in case of inconsistency ###
      def new_pg_verify_checksum(paytmparams, check_sum, key = preferred_merchant_key, salt_length = 4)
        return false if paytmparams.class != Hash
        return false if key.empty?
        return false if check_sum.nil? || check_sum.empty?

        generated_check_sum = nil

        check_sum = new_pg_decrypt_variable(check_sum, key)
        return false if check_sum == false

        begin
          salt = check_sum[(check_sum.length - salt_length), check_sum.length]
          keys = paytmparams.keys
          str = nil
          keys = keys.sort
          keys.each do |k|
            if str.nil?
              str = paytmparams[k].to_s
              next
            end
            str = "#{str}|#{paytmparams[k]}"
          end
          str = "#{str}|#{salt}"
          generated_check_sum = Digest::SHA256.hexdigest(str)
          generated_check_sum += salt
        rescue Exception => e
          return false
        end

        check_sum == generated_check_sum
      end

      private

      def domain
        preferred_test_mode == true ? 'securegw-stage.paytm.in' : 'securegw.paytm.in'
      end
    end
  end
end
