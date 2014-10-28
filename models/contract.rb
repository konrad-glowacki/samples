class Contract < ActiveRecord::Base

  include Activity::Fires
  include Contract::Status
  include Contract::DocumentType
  include Contract::RenewalType
  include Contract::PaymentType
  include Contract::InvoiceAddress

  INVOICE_TYPES = [:single, :multi]
  EXPIRES       = [15, 30, 45, 60]

  has_and_belongs_to_many :deliveries

  belongs_to :user
  belongs_to :customer
  belongs_to :agent,           class_name: 'Stakeholder'
  belongs_to :consultant,      class_name: 'Stakeholder'
  belongs_to :subscriber_rid,  class_name: 'Stakeholder'
  belongs_to :sale_price_list, class_name: 'PriceList'

  has_many :attachments, as: :with_attachment, dependent: :destroy, order: 'created_at DESC'
  has_many :comments,    as: :commentable,     dependent: :destroy
  has_many :messages,    as: :entity
  has_many :emails,      as: :emailable,       dependent: :destroy
  has_many :phones,      as: :phonable,        dependent: :destroy

  has_many :stakeholder_connections, as: :relation, dependent: :destroy
  has_many :stakeholders, through: :stakeholder_connections

  scope :default_order, order('id DESC')
  scope :by_state, ->(state) { where(state: state.to_s) }

  monetize :agent_bonus_cents, allow_nil: true, numericality: { greater_than_or_equal_to: 0 }
  monetize :agent_fee_cents,   allow_nil: true, numericality: { greater_than_or_equal_to: 0 }

  available_statuses :ok, :error
  default_value_for :status, 'ok'

  available_document_types :original, :copy_scan, :copy_fax
  default_value_for :document_type, 'original'

  available_renewal_types :tacit, :contractual
  default_value_for :renewal_type, 'tacit'

  available_payment_types :bank, :rid, :postal_bulletin, :credit_card
  default_value_for :payment_type, 'bank'

  validates_presence_of :user_id, :customer_id, :agent_id, :consultant_id
  validates :plico, presence: true, uniqueness: true
  validates :document_type, inclusion: document_types.map(&:to_s), allow_blank: true
  validates :payment_type,  inclusion: payment_types.map(&:to_s), allow_blank: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :invoice_shipping, presence: true, inclusion: Contract::InvoiceShipping.all.map(&:id)

  validates :expiry,       presence: true, numericality: { only_integer: true }, inclusion: EXPIRES
  validates :renewal_type, presence: true, inclusion: self.renewal_types.map(&:to_s)
  validate  :other_contracts_periods
  validates :invoice_type, presence: true, inclusion: { in: INVOICE_TYPES.map(&:to_s) }

  accepts_nested_attributes_for :deliveries, :emails, :phones, allow_destroy: true

  @accessible = [:plico, :signed_at, :document_type, :deliveries_attributes, :start_date, :end_date, :payment_type, :iban, :subscriber_rid_id, :header_account, :credit_institute, :state_alignment, :request_data_alignment, :data_alignment, :state, :agent_id, :consultant_id, :customer_id, :expiry, :agent_bonus, :agent_fee, :state_description, :renewal_type, :cgf_code, :rid_signed_at, :phones_attributes, :emails_attributes, :invoice_shipping, :invoice_address_street, :invoice_address_province_id, :invoice_address_comune_id, :invoice_address_zip_code_id, :delivery_id, :invoice_type, :sale_price_list_id, :user_id]

  attr_accessible *@accessible
  attr_accessible *@accessible, as: :admin
  attr_accessor :delivery_id

  state_machine :state, :initial => :backoffice_acquisition do
    before_transition on: :welcoming, do: :valid_dependencies
    after_transition  on: :welcoming, do: :send_welcome_email

    event :welcoming do
      transition [:backoffice_acquisition, :check_contract] => :check_contract
    end

    state :check_contract do

    end

    state :check_recall do

    end

    state :recall_failed do

    end

    state :failed do

    end

    state :suspended do

    end

    state :accepted do

    end

    state :sending_welcome_letter do

    end
  end

  # HELPERS

  def consumption
    deliveries.sum(:usage_estimate)
  end

  def esteemed
    kind_id = Stakeholder.kind_id_by_name(:coordinator_referent)
    stakeholders.detect { |s| s.kind_ids.include?(kind_id.to_s) } || customer.legal_representant
  end

  def contract_type
    types = deliveries.map(&:delivery_type).uniq
    types.size > 1 ? 'dual' : types.first
  end

  def to_s
    "#{plico} - #{customer}"
  end

  def is_active_by_date?(check_date = nil)
    if start_date && end_date
      check_date =  Date.today unless check_date
      (start_date..end_date).include?(check_date)
    end
  end

  def soft_save
    self.status = 'error' unless valid?
    save(validate: false)
  end

  def valid_dependencies
    customer.contact_email.present? && deliveries.any?
  end

  def send_welcome_email
    message = Message.new(email_type: :welcome, entity: self)
    mailer  = ContractMailer.welcome(self, message.uuid)

    message.assign_attributes(recipient: mailer.to.join(', '), subject: mailer.subject, body: mailer.body.to_s)
    mailer.deliver && message.save
  end

  def as_json(options = {})
    {
      id:              id,
      plico:           plico,
      label:           plico,
      customer:        customer.name,
      customer_id:     customer.id,
      start_date:      start_date.nil? ? '' : start_date.strftime("%d/%m/%Y"),
      end_date:        end_date.nil? ? '' : end_date.strftime("%d/%m/%Y"),
      state:           I18n.t("activerecord.values.contract.state.#{state}")
    }
  end

  def emails_list
    list = emails.map(&:address) + customer.emails_list
    list.compact.map { |email| email.downcase }.uniq
  end

  class << self
    def expires
      EXPIRES
    end

    def states
      self.state_machine.states.map(&:name)
    end

    def invoice_types
      INVOICE_TYPES
    end
  end

  private

    def other_contracts_periods
      if delivery_id.present? && start_date && end_date
        Delivery.find_by_id(delivery_id).contracts.each do |contract|
          period     = contract.start_date..contract.end_date
          new_period = start_date..end_date

          if period.include?(start_date) || period.include?(end_date) || new_period.include?(period)
            errors.add(:start_date, :overlap)
            break
          end
        end
      end
    end

end
