require 'spec_helper'

describe Tutors::CreateService do
  describe '#execute' do
    let(:tutor) { build(:tutor, user: nil) }
    let(:partner_id) { 1 }
    let(:partner_info) { 'StudiVZ' }
    let(:landingpage) { '/some-page' }

    context 'has only tutor arg' do
      subject { described_class.new(tutor) }

      before {
        allow(TutorNotification).to receive(:account_activation)
      }

      it 'creates a tutor and associate user' do
        expect { subject.execute }.to_not raise_error

        expect(TutorNotification).to have_received(:account_activation).with(tutor.user).once
        expect(subject.tutor).to be_persisted
        expect(subject.tutor.user).to be_persisted
        expect(subject.tutor.teaching_since).to be_present
        expect(subject.tutor.activated_key).to be_present
        expect(subject.tutor.user.activated).to be_truthy
        expect(subject.tutor.user.subscribes_newsletter).to be_falsey
        expect(subject.tutor.full_name).to eq(subject.tutor.user.full_name)
      end

      it 'updates registration_step to registration path' do
        expect {
          subject.execute
        }.to change(tutor, :registration_step).to('/tutor_registration/locations')
      end
    end

    context 'has only tutor and cookies args' do
      let(:cookies) do
        {
          landingpage_url: landingpage,
          aff: [partner_id],
          aff_info: [partner_info]
        }
      end

      subject { described_class.new(tutor, cookies) }

      it 'creates a tutor and associate user' do
        expect { subject.execute }.to_not raise_error
        expect(tutor.landingpage_url).to eq(landingpage)
        expect(tutor.partner_id).to eq(partner_id)
        expect(tutor.partner_info).to eq(partner_info)
      end
    end
  end

end
