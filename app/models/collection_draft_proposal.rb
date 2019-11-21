class CollectionDraftProposal < CollectionDraft
  include AASM
  self.table_name = 'draft_proposals'
  validates :request_type, presence: true
  validates :proposal_status, presence: true

  scope :publish_approved_proposals, -> { select(CollectionDraftProposal.attribute_names - %w[approver_feedback]).where(proposal_status: 'approved') }

  # after_initialize :exception_unless_draft_only
  # after_find :exception_unless_draft_only

  # before_validation :proposal_mode?
  before_create :proposal_mode_enabled?
  before_save :proposal_mode_enabled?
  before_update :proposal_mode_enabled?
  before_destroy :proposal_mode_enabled?

  serialize :status_history, JSON
  serialize :approver_feedback, JSON

  class << self
    def create_request(collection:, user:, provider_id:, native_id:, request_type:, username: nil)
      request = self.create
      request.request_type = request_type
      request.provider_id = provider_id
      request.native_id = native_id
      request.draft = collection
      request.short_name = request.draft['ShortName']
      request.entry_title = request.draft['EntryTitle']
      request.user = user

      if request_type == 'delete'
        request.submit
        request.status_history =
          { 'submitted' =>
            { 'username' => (username || user.urs_uid), 'action_date' => Time.new.utc.to_s } }
      end

      request.save
      request
    end
  end

  aasm column: 'proposal_status', whiny_transitions: false do
    state :in_work, initial: true
    state :submitted
    state :rejected
    state :approved
    state :done

    event :submit do
      transitions from: :in_work, to: :submitted
    end

    event :rescind do
      transitions from: :submitted, to: :in_work
      transitions from: :rejected, to: :in_work
    end

    event :approve do
      transitions from: :submitted, to: :approved
    end

    event :reject do
      transitions from: :submitted, to: :rejected
    end
  end

  def default_values
    super
    self.status_history ||= {}
    self.approver_feedback ||= {}
  end

  def add_status_history(target, name)
    self.status_history[target] = { 'username' => name, 'action_date' => Time.new }
  end

  def remove_status_history(target)
    self.status_history.delete(target)
  end

  def progress_message(action)
    status = self.status_history.fetch(action, {})
    if status.blank?
      action_time = 'No Date Provided'
      action_username = 'No User Provided'
      unless in_work?
        Rails.logger.error("A #{self.class} with title #{entry_title} and id #{id} is being asked for a status_history for #{action}, but does not have that information. This proposal should be investigated.")
      end
    else
      action_time = status['action_date'].in_time_zone('UTC').to_s(:default_with_time_zone)
      action_username = status['username']
    end

    action_name = action == 'done' ? 'Published' : action.titleize

    "#{action_name}: #{action_time} By: #{action_username}"
  end

  private

  def provider_required?
    # new (create) proposals do not have a provider
    # but update and delete proposals should have a provider, but from the record it is created from
    false
  end

  def proposal_mode_enabled?
    # TODO this will work until we update to Rails 5
    # https://blog.bigbinary.com/2016/02/13/rails-5-does-not-halt-callback-chain-when-false-is-returned.html
    Rails.configuration.proposal_mode
  end

  def exception_unless_draft_only
    # TODO: these require an exception raised to halt execution (see rails guides)
    # documentation says this exception should not bubble up to the user
    # so we should see if we can use this when we start CRUD
    raise ActiveRecord::Rollback unless Rails.configuration.proposal_mode
  end
end
