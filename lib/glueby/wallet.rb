# frozen_string_literal: true

module Glueby
  class Wallet
    attr_reader :internal_wallet

    class << self
      def create
        new(Glueby::Internal::Wallet.create)
      end

      def load(wallet_id)
        new(Glueby::Internal::Wallet.load(wallet_id))
      end

      def configure(config)
        case config[:adapter]
        when 'core'
          Glueby::Internal::RPC.configure(config)
          Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::TapyrusCoreWalletAdapter.new
        else
          raise 'Not implemented'
        end
      end
    end

    def id
      @internal_wallet.id
    end

    # @return [HashMap] hash of balances which key is color_id or empty string, and value is amount
    def balances
      utxos = @internal_wallet.list_unspent
      utxos.inject({}) do |balances, output|
        script = Tapyrus::Script.parse_from_payload(output[:script_pubkey].htb)
        key = if script.cp2pkh? || script.cp2sh?
                Tapyrus::Color::ColorIdentifier.parse_from_payload(script.chunks[0].pushed_data).to_hex
              else
                ''
              end
        balances[key] ||= 0
        balances[key] += output[:amount]
        balances
      end
    end

    private

    def initialize(internal_wallet)
      @internal_wallet = internal_wallet
    end
  end
end