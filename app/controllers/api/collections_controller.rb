class Api::CollectionsController < Api::BaseController
  include ManageMetadataHelper
  include PiqToDraft
  skip_authenticity_token

  def create
    message = 'Request params are not a valid collection draft.'
    status = :unprocessable_entity
    errors = []

    if PiqToDraft.valid?(params)
      user = User.where(urs_uid: 'piq_user').last || User.create({
        urs_uid: 'piq_user',
        provider_id: 'NASA_MAAP'
      })
      user.save!

      native_id = params[:collection_info][:short_title]
      draft = CollectionDraft.find_or_create_by(native_id: native_id)
      draft.draft = {}
      draft.provider_id = 'NASA_MAAP'
      converted_draft = PiqToDraft.convert(params)
      draft.update_draft(converted_draft, user.id)
      message = "Failed to save draft with with native_id: #{native_id}.\n"

      if draft.save
        message = 'Collection Draft created.'
        status = :created
      else
        errors = draft.errors
      end
    end

    render json: { message: message, errors: errors }, status: status
  end
end
