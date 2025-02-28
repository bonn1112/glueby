module Glueby
  module Contract
    module FeeEstimator
      # It calculates actual minimum fee to broadcast txs.
      class Auto
        include FeeEstimator

        # This is same with Tapyrus Core's default min_relay_fee value.(tapyrus/kB)
        DEFAULT_FEE_RATE = 1_000

        # @!attribute [r] fee_rate
        #  @return [Integer] the fee rate(tapyrus/kB) that is used actual fee calculation
        attr_reader :fee_rate

        class << self
          # @!attribute [rw] default_fee_rate
          #  @return [Integer] The global fee rate configuration. All instances use this value as the default.
          attr_accessor :default_fee_rate
        end

        # @param [Integer] fee_rate
        def initialize(fee_rate: Auto.default_fee_rate || DEFAULT_FEE_RATE)
          @fee_rate = fee_rate
        end

        private

        def estimate_fee(tx)
          ((tx.to_payload.bytesize / 1000.0) * fee_rate).ceil
        end
      end
    end
  end
end
