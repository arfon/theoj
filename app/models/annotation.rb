class Annotation < ActiveRecord::Base
  include AASM

  belongs_to :paper,      inverse_of: :annotations
  belongs_to :assignment, inverse_of: :annotations

  has_many   :responses, class_name:'Annotation', foreign_key:'parent_id'
  belongs_to :parent,    class_name:'Annotation', foreign_key:'parent_id'

  scope :root_annotations , -> { where(parent_id: nil) }

  before_validation :set_defaults
  after_save        :push_to_firebase

  validates :body,
            presence:true
  validates :paper_id,
            presence:true
  validates :assignment_id,
            presence:true
  validate do
    errors.add(:assignment, 'must belong to the same paper') unless !paper_id || paper.assignments.include?(assignment)
  end
  validate do
    errors.add(:parent, 'must belong to the same paper') unless parent_id.nil? || parent.paper_id == paper_id
  end

  aasm column: :state, no_direct_assignment:true do
    state :unresolved,       initial:true
    state :resolved
    state :disputed

    event :unresolve, guard: :can_change_state? do
      transitions to: :unresolved
    end

    event :resolve, guard: :can_change_state? do
      transitions to: :resolved
    end

    event :dispute, guard: :can_change_state? do
      transitions to: :disputed
    end

  end

  def base_annotation
    parent_id.nil? ? self : parent
  end

  def user
    assignment.user
  end

  def firebase_key
    "#{paper.firebase_key}/annotations/#{base_annotation.id}"
  end

  def push_to_firebase
    # Note this must be anonymized user data
    # Rails.logger.debug("PUSHING TO FIREBASE: #{firebase_key}:: #{base_annotation.inspect}")
    # FirebaseClient.set firebase_key, AnnotationSerializer.new(base_annotation).as_json
  end

  # Is this a root issue?
  def is_issue?
    parent_id.nil?
  end

  def is_response?
    parent_id
  end

  def has_responses?
    responses.any?
  end

  private

  def can_change_state?
    return false unless is_issue? && paper
    return true if paper.under_review?

    # Can resolve while paper is being accepted
    return true if paper.aasm.current_event.in?([:accept, :accept!]) && aasm.to_state==:resolved
    return false
  end

  def set_defaults
    self.paper_id = parent.paper_id if parent_id && !paper_id
  end

end
