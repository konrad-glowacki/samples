module Tutors
  class CreateService
    attr_reader :tutor, :cookies

    def initialize(tutor, cookies = {})
      @tutor = tutor
      @cookies = cookies
    end

    def execute
      tutor.registration_step = '/nachhilfe-geben'
      tutor.valid?

      Tutor.transaction do
        tutor.user = create_user!
        tutor.landingpage_url = cookies[:landingpage_url]
        tutor.initial_password = get_initial_password
        tutor.init_teaching_since
        tutor.create_activated_key
        tutor.save!

        TutorNotification.account_activation(tutor.user)
        tutor.set_partner_info(cookies)
      end

      tutor.update_column(:registration_step, '/tutor_registration/locations')
    end

    private

    def get_initial_password
      @initial_password ||= SecureRandom.hex.first(10)
    end

    def create_user!
      User.new_from(
        tutor,
        password_changed: true,
        subscribes_newsletter: tutor.subscribes_newsletter,
        password: get_initial_password
      ).tap(&:save!)
    end
  end
end
