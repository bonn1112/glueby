# frozen_string_literal: true

RSpec.describe 'Glueby::Internal::Wallet::ActiveRecordWalletAdapter', active_record: true do
  let(:adapter) { Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new }
  let(:wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000000') }

  describe '#create_wallet' do
    subject { adapter.create_wallet }

    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1) }

    context 'specify wallet_id' do
      subject { adapter.create_wallet('wallet') }

      it 'create a new wallet with the wallet_id' do
        expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1)
        expect(Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: 'wallet')).not_to be_nil
      end

      context 'wallet_id is already exist' do
        before do
          adapter.create_wallet('wallet')
        end

        it 'raise an error' do
          expect { subject }.to raise_error(error=Glueby::Internal::Wallet::Errors::WalletAlreadyCreated, message="wallet_id 'wallet' is already exists")
        end
      end

      context 'as nil' do
        subject { adapter.create_wallet(nil) }

        it 'create a new wallet with random wallet_id' do
          expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1)
          expect(Glueby::Internal::Wallet::AR::Wallet.first.wallet_id).to match(/[0-9a-f]{32}/)
        end
      end
    end
  end

  describe '#load_wallet' do
    subject { adapter.load_wallet(wallet_id) }

    let(:wallet_id) { '0828d0ce8ff358cd0d7b19ac5c43c3bb' }

    context 'wallet is exists' do
      before do
        adapter.create_wallet(wallet_id)
      end

      it 'never raise errors' do
        expect { subject }.not_to raise_error
      end
    end

    context 'wallet is not exists' do
      it 'raise an error' do
        expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::WalletNotFound, "Wallet #{wallet_id} does not found")
      end
    end
  end

  describe '#delete_wallet' do
    it do
      wallet_id = adapter.create_wallet
      expect { adapter.delete_wallet(wallet_id) }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(1).to(0)
    end
  end

  describe '#wallets' do
    subject { adapter.wallets }

    before do
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000001')
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000003')
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000002')
    end

    it { expect(subject).to eq ['00000000000000000000000000000001', '00000000000000000000000000000002', '00000000000000000000000000000003'] }
  end

  describe '#balance' do
    subject { adapter.balance(wallet.wallet_id, only_finalized) }

    let(:other_wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: adapter.create_wallet) }
    let(:only_finalized) { true }
    let(:key1) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key1, purpose: :receive, wallet: wallet) }
    let(:private_key1) { '1000000000000000000000000000000000000000000000000000000000000000' }
    let(:key2) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key2, purpose: :receive, wallet: wallet) }
    let(:private_key2) { '2000000000000000000000000000000000000000000000000000000000000000' }
    let(:key3) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key3, purpose: :receive, wallet: other_wallet) }
    let(:private_key3) { '3000000000000000000000000000000000000000000000000000000000000000' }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a9140ff36d308d250261c518f2db838f12775476a49788ac',
        value: 1,
        status: :broadcasted,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 1,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 2,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 2,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 3,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 3,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 4,
        status: :init,
        key: key3
      )
    end

    context 'finalized only' do
      it { is_expected.to eq 5 }
    end

    context 'with unconfirmed' do
      let(:only_finalized) { false }
      it { is_expected.to eq 6 }
    end
  end

  describe '#list_unspent' do
    shared_examples 'executes the common unlabeled validation' do
      it { expect(subject.count).to eq 2 }
      it { expect(subject[0][:vout]).to eq 1 }
      it { expect(subject[0][:label]).to eq nil }
      it { expect(subject[1][:vout]).to eq 2 }
      it { expect(subject[1][:label]).to eq nil }
    end

    subject { adapter.list_unspent(wallet.wallet_id, only_finalized, label) }

    let(:other_wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: adapter.create_wallet) }
    let(:only_finalized) { true }
    let(:label) { nil }
    let(:key1) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key1, purpose: :receive, wallet: wallet) }
    let(:private_key1) { '1000000000000000000000000000000000000000000000000000000000000000' }
    let(:key2) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key2, purpose: :receive, wallet: wallet) }
    let(:private_key2) { '2000000000000000000000000000000000000000000000000000000000000000' }
    let(:key3) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key3, purpose: :receive, wallet: other_wallet) }
    let(:private_key3) { '3000000000000000000000000000000000000000000000000000000000000000' }
    let(:key4) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key4, purpose: :receive, wallet: wallet) }
    let(:private_key4) { '4000000000000000000000000000000000000000000000000000000000000000' }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000001',
        index: 0,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a9140ff36d308d250261c518f2db838f12775476a49788ac',
        value: 1,
        status: :broadcasted,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000002',
        index: 1,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 2,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000003',
        index: 2,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 3,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000004',
        index: 3,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 4,
        status: :init,
        key: key3
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000004',
        index: 4,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 5,
        status: :finalized,
        key: key4,
        label: 'Glueby-Contract-Tracking'
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000004',
        index: 5,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 6,
        status: :broadcasted,
        key: key4,
        label: 'Glueby-Contract-Tracking'
      )
    end

    context 'finalized only' do
      # get only unlabeled utxos because of default
      it { expect(subject.count).to eq 2 }
      it { expect(subject[0][:vout]).to eq 1 }
      it { expect(subject[0][:finalized]).to be_truthy }
      it { expect(subject[1][:vout]).to eq 2 }
      it { expect(subject[1][:finalized]).to be_truthy }
    end

    context 'with unconfirmed' do
      let(:only_finalized) { false }

      it { expect(subject.count).to eq 3 }
      it { expect(subject[0][:vout]).to eq 0 }
      it { expect(subject[0][:finalized]).to be_falsy }
      it { expect(subject[1][:vout]).to eq 1 }
      it { expect(subject[1][:finalized]).to be_truthy }
      it { expect(subject[2][:vout]).to eq 2 }
      it { expect(subject[2][:finalized]).to be_truthy }
    end

    context 'with unlabeled' do
      let(:label) { :unlabeled }
      it_behaves_like 'executes the common unlabeled validation'
    end

    context 'with unlabeled by default' do
      it_behaves_like 'executes the common unlabeled validation'
    end

    context "with 'Glueby-Contract-Tracking' labeled utxos" do
      let(:only_finalized) { false }
      let(:label) { 'Glueby-Contract-Tracking' }

      it { expect(subject.count).to eq 2 }
      it { expect(subject[0][:vout]).to eq 4 }
      it { expect(subject[0][:label]).to eq 'Glueby-Contract-Tracking' }
      it { expect(subject[1][:vout]).to eq 5 }
      it { expect(subject[1][:label]).to eq 'Glueby-Contract-Tracking' }
    end

    context "with all utxos" do
      let(:label) { :all }
      let(:only_finalized) { false }

      it { expect(subject.count).to eq 5 }
      it { expect(subject[0][:vout]).to eq 0 }
      it { expect(subject[0][:finalized]).to be_falsy }
      it { expect(subject[1][:vout]).to eq 1 }
      it { expect(subject[1][:finalized]).to be_truthy }
      it { expect(subject[2][:vout]).to eq 2 }
      it { expect(subject[2][:finalized]).to be_truthy }
      it { expect(subject[3][:vout]).to eq 4 }
      it { expect(subject[3][:label]).to eq 'Glueby-Contract-Tracking' }
      it { expect(subject[4][:vout]).to eq 5 }
      it { expect(subject[4][:label]).to eq 'Glueby-Contract-Tracking' }
    end
  end

  describe '#receive_address' do
    subject { adapter.receive_address(wallet.wallet_id) }

    it { expect { subject }.to change { wallet.keys.where(purpose: :receive).count }.from(0).to(1) }
    it { expect { subject }.not_to change { wallet.keys.where(purpose: :change).count } }
    it { expect { Tapyrus.decode_base58_address(subject) }.not_to raise_error }

    context 'with label' do
      subject { adapter.receive_address(wallet.wallet_id, 'tracking') }

      it { expect { subject }.to change { wallet.keys.where(purpose: :receive, label: 'tracking').count }.from(0).to(1) }
    end
  end

  describe '#change_address' do
    subject { adapter.change_address(wallet.wallet_id) }

    it { expect { subject }.to change { wallet.keys.where(purpose: :change).count }.from(0).to(1) }
    it { expect { subject }.not_to change { wallet.keys.where(purpose: :receive).count } }
    it { expect { Tapyrus.decode_base58_address(subject) }.not_to raise_error }
  end

  describe '#create_pubkey' do
    subject do
      pubkey = adapter.create_pubkey(wallet.wallet_id)
      pubkey.fully_valid_pubkey?
    end

    it { expect { subject }.to change { wallet.keys.count }.from(0).to(1) }
    it { expect(subject).to be_truthy }
  end

  describe '#get_addresses' do
    subject { adapter.get_addresses(wallet.wallet_id) }

    before do
      adapter.receive_address(wallet.wallet_id)
      adapter.receive_address(wallet.wallet_id, 'tracking')
    end

    it { expect(subject.count).to eq 2 }
    it { expect(Tapyrus.valid_address?(subject[0])).to be_truthy }
    it { expect(Tapyrus.valid_address?(subject[1])).to be_truthy }

    context 'with label' do
      subject { adapter.get_addresses(wallet.wallet_id, 'tracking') }

      it { expect(subject.count).to eq 1 }
    end
  end

  describe '#broadcast' do
    subject { adapter.broadcast(wallet.wallet_id, tx) }
    let(:tx) { Tapyrus::Tx.new }
    let(:rpc) { double('mock') }

    before do
      allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    end

    it 'calls sendrawtransaction RPC' do
      expect(Glueby::Internal::RPC.client).to receive(:sendrawtransaction).with(tx.to_hex)
      subject
    end

    context 'given a block' do
      it 'calls the block with tx that is in arguments' do
        expect(Glueby::Internal::RPC.client).to receive(:sendrawtransaction).with(tx.to_hex)
        adapter.broadcast(wallet.wallet_id, tx) do |tx_arg|
          expect(tx).to eq tx_arg
        end
      end
    end
  end

  describe '#create_pay_to_contract_address' do
    subject { adapter.create_pay_to_contract_address(wallet.wallet_id, 'contents') }

    it { expect { subject }.to change { wallet.keys.where(purpose: :receive).count }.from(0).to(1) }
    it { expect { subject }.not_to change { wallet.keys.where(purpose: :change).count } }
    it { expect { Tapyrus.decode_base58_address(subject[0]) }.not_to raise_error }
  end

  describe '#sign_to_pay_to_contract_address' do
    subject { adapter.sign_to_pay_to_contract_address(wallet.wallet_id, tx, utxo, payment_base, contents)}

    let(:tx) { Tapyrus::Tx.parse_from_payload('0100000002f27e1bf8f372cc149a3ab29813e01c1482b271608ba26bdf737abaa9322550140000000000ffffffff153ba5cb9832474c1a19877824b01960dc0e81d9bac5a0a568b608557d79498e00000000644110ce5ba4c4c13ae914e6f3abb2f248ee622423a0d83f4a7ae0c080178b5a967c1fed066eba4c6489f679e79cada9f167e4d65dd2d0183f0db1a6220de93ce52401210211e33617dcdf5732056c441b918b4ae6c5269f6fba1547e3b9ef6cbaaebeb2b6ffffffff01e8030000000000001976a91494ccd55800015cd996281aaca5f60f25d173af3d88ac00000000'.htb) }
    let(:utxo) do
      {
        txid: '14502532a9ba7a73df6ba28b6071b282141ce01398b23a9a14cc72f3f81b7ef2',
        vout: 0,
        amount: 1000,
        script_pubkey: '76a914539b48fe6cebb55c207e150b4e2443210b7e971088ac'
      }
    end
    let(:payment_base) { '02046e89be90d26872e1318feb7d5ca7a6f588118e76f4906cf5b8ef262b63ab49' }
    let(:contents) { 'app5ae7e6a42304dc6e4176210b83c43024f99a0bce9a870c3b6d2c95fc8ebfb74c' }

    before do
      Glueby::Internal::Wallet::AR::Key.create!(
        private_key: 'c5580f6c26f83fb513dd5e0d1b03c36be26fcefa139b1720a7ca7c0dedd439c2',
        public_key: '02046e89be90d26872e1318feb7d5ca7a6f588118e76f4906cf5b8ef262b63ab49',
        script_pubkey: '76a9141747ad39deefc57d933d0d625f7f71ca6fcc688d88ac',
        label: nil,
        purpose: 'receive',
        wallet_id: wallet.id
      )
    end

    it do
      expect(subject.inputs[0].script_sig.to_hex).to eq '41c88a45a008be7bbdac85b400085ed24f30adf6f9c7c86556a794ffd3d5e2b7dda128dccc3dbe24e5b59793bf3e4ad5a00f98c408d736b166a334a3c8e2297e420121021d25c88f2cd16e317156b6bf9870b08f5e6d782ca653473cee9c7a6746cac58c'
    end
  end
end
