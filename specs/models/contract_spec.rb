require 'spec_helper'

describe Contract do

  context 'class methods' do
    describe '.document_types' do
      its(:document_types) { should include(:original, :copy_scan, :copy_fax) }
    end

    describe '.statuses' do
      its(:statuses) { should include(:ok, :error) }
    end

    describe '.invoice_types' do
      it { described_class.invoice_types.should include(:single, :multi) }
    end

    describe '.expires' do
      it { described_class.expires.should include(15, 30, 45, 60) }
    end
  end

  context 'has 2 contracts with different period' do
    let(:contract) { create(:contract, start_date: periods.first[:start_date], end_date: periods.first[:end_date]) }
    let(:delivery) { create(:power_delivery, contracts: [contract]) }

    subject { build(:contract, delivery_id: delivery.id, start_date: periods.second[:start_date], end_date: periods.second[:end_date]) }

    context 'periods not overlap' do
      let(:periods) do
        [{ start_date: 2.months.ago.to_date, end_date: 1.month.ago.to_date }, { start_date: 1.month.since.to_date, end_date: 2.months.since.to_date }]
      end

      its(:delivery_id) { should == delivery.id }
      it { subject.valid?.should be_truthy }
    end

    context 'periods is overlap' do
      context 'some part' do
        let(:periods) do
          [{ start_date: 30.days.ago.to_date, end_date: 1.day.ago.to_date }, { start_date: 10.days.ago.to_date, end_date: 15.days.since.to_date }]
        end

        it { subject.valid?.should be_falsey }
        it { should have(1).errors_on(:start_date) }
      end

      context 'new period include period' do
        let(:periods) do
          [{ start_date: 20.days.ago.to_date, end_date: 10.day.ago.to_date }, { start_date: 30.days.ago.to_date, end_date: 5.days.ago.to_date }]
        end

        it { subject.valid?.should be_falsey }
        it { should have(1).errors_on(:start_date) }
      end
    end
  end

  context 'after create' do
    subject { create(:contract, plico: 'AGV12345678-8437') }

    describe "#signed_at" do
     its(:signed_at) { should be_kind_of(Date) }
    end

    describe '.to_s' do
      its(:to_s) { should == 'AGV12345678-8437 - John home Doe' }
    end

    describe '#rid_signed_at' do
      let(:date_example) { '10/05/2013' }

      before {
        subject.rid_signed_at = date_example
        subject.save
        subject.reload
      }

      its(:rid_signed_at) { should be_kind_of(Date) }
      its(:rid_signed_at) { should == Date.parse(date_example) }
    end

    [:agent_bonus, :agent_fee].each do |column|
      describe "##{column}" do
        let(:price) { '23,43' }
        before {
          subject.send("#{column}=", price)
          subject.save
        }

        it { subject.send(column).to_s.should == price }
        it { subject.send(column).currency.to_s.should == 'EUR' }
      end
    end

    context 'defalut values' do
      describe '#document_type' do
        its(:document_type) { should == 'original' }
      end

      describe '#expiry' do
        its(:expiry) { should == 15 }
      end

      describe '#renewal_types' do
        its(:renewal_type) { should == 'tacit' }
      end

      describe '#agent_bonus' do
        its(:agent_bonus) { should be_nil }
      end

      describe '#agent_fee' do
        its(:agent_fee) { should be_nil }
      end

      describe '#contract_type' do
        its(:contract_type) { should be_nil }
      end

      describe '#status' do
        its(:status) { should == 'ok' }
      end

      describe '#invoice_type' do
        its(:invoice_type) { should == Contract.invoice_types.first.to_s }
      end

      context 'dynamic helpers' do
        its(:ok?) { should be_truthy }
        its(:error?) { should be_falsey }

        its(:original?) { should be_truthy }
        its(:copy_scan?) { should be_falsey }
        its(:copy_fax?) { should be_falsey }
      end

      describe '#delivery_id' do
        its(:delivery_id) { should be_nil }
      end
    end

    describe '#delivery_id' do
      before { subject.delivery_id = 5 }
      its(:delivery_id) { should == 5 }
    end

    context 'no deliveries' do
      before { subject.deliveries = [] }
      it { subject.valid_dependencies.should be_falsey }
    end

    context '1 deliveries' do
      before { subject.deliveries = [create(:power_delivery)] }

      context 'contract_email is empty' do
        before { subject.customer.contact_email = '' }
        it { subject.valid_dependencies.should be_falsey }
      end

      context 'contract_email is not empty' do
        before { subject.customer.contact_email = 'test@webmonks.it' }
        it { subject.valid_dependencies.should be_truthy }

        ['backoffice_acquisition', 'check_contract'].each do |state|
          context "has state #{state}" do
            before { subject.update_column(:state, state) }

            specify {
              subject.welcoming.should be_truthy
              Message.last.entity == subject
            }
          end
        end
      end
    end

    context 'validations' do
      let(:gas_delivery)   { build(:gas_delivery) }
      let(:gas_delivery_2) { build(:gas_delivery) }
      let(:gas_delivery_3) { build(:gas_delivery) }

      let(:power_delivery)   { build(:power_delivery) }
      let(:power_delivery_2) { build(:power_delivery) }
      let(:power_delivery_3) { build(:power_delivery) }

      context 'not valid' do

        describe '#expiry' do
          before { subject.expiry = 'aaa' }
          it { subject.should have(2).errors_on(:expiry) }
        end

        describe '#renewal_type' do
          before { subject.renewal_type = 'spaghetti' }
          it { subject.should have(1).errors_on(:renewal_type) }
        end

      end

      context 'valid' do
        context 'state is backoffice_acquisition and deliveries is empty' do
          before {
            subject.state = 'backoffice_acquisition'
            subject.deliveries = []
          }

          it { should be_valid }
          its(:contract_type) { should be_nil }
        end

        context 'deliveries are 3 type of gas' do
          before { subject.deliveries = [gas_delivery, gas_delivery_2, gas_delivery_3] }

          specify {
            should be_valid
            subject.contract_type.should == 'gas'
          }
        end

        context 'deliveries are 3 type of gas' do
          before { subject.deliveries = [power_delivery, power_delivery_2, power_delivery_3] }

          specify {
            should be_valid
            subject.contract_type.should == 'power'
          }
        end

        context 'deliveries are 2 type of gas and 2 type of power' do
          before { subject.deliveries = [power_delivery, gas_delivery, power_delivery_2, gas_delivery_2] }

          specify {
            should be_valid
            subject.contract_type.should == 'dual'
          }
        end
      end

    end
  end

  describe '#emails_list' do
    it 'returns all the emails associated with this customer' do
      customer = create(:home_customer_with_emails)
      contract = create(:contract_with_emails, customer: customer)
      expect(contract.emails_list.count).to eq(4)
    end
  end

end
