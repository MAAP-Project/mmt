# :nodoc:
class VariableDraftsController < BaseDraftsController
  include ControlledKeywords

  before_action :set_resource, only: [:show, :edit, :update, :destroy, :update_associated_collection]
  before_action :ensure_published_record_supported_version, only: [:show, :edit]
  before_action :set_schema, only: [:show, :new, :edit, :update, :create]
  before_action :set_form, only: [:show, :edit, :update]
  before_action :set_current_form, only: [:edit]
  before_action :set_preview, only: [:show]

  def edit
    super

    set_science_keywords if @current_form == 'science_keywords'
    set_measurement_names if @current_form == 'measurement_identifiers'
  end

  def show
    # search for a variable by native id
    variable_params = { native_id: get_resource.native_id, provider: get_resource.provider_id }
    variable_search_response = cmr_client.get_variables(variable_params, token)
    if variable_search_response.success?
      @editing = variable_search_response.body['hits'].to_i > 0 ? true : false
    else
      Rails.logger.error("Error searching for published Variable in VariableDraftsController#show: #{variable_search_response.clean_inspect}")
      @editing = true
    end

    super
  end

  def update_associated_collection
    authorize get_resource

    params.permit(:id, :selected_collection)

    # TODO: When clearing a collection association, the value becomes an empty string. should that change?

    if get_resource.update(collection_concept_id: params[:selected_collection])
      flash[:success] = I18n.t("controllers.draft.variable_drafts.update_associated_collection.flash.success")
    else
      flash[:error] = I18n.t("controllers.draft.variable_drafts.update_associated_collection.flash.error")
    end
    redirect_to send("#{resource_name}_path", get_resource)
  end

  private

  def set_schema
    @schema = UmmJsonSchema.new(plural_published_resource_name, 'umm-var-json-schema.json')
    @schema.fetch_references(@schema.parsed_json)
  end

  def set_form
    # Disable the name field if CMR already has this variable.
    # CMR will reject it if the name changes, so we shouldn't let the user try
    # Just having params[:form]... on the left side causes it to hit CMR when
    # leaving the form too.
    if (params[:form] == 'variable_information' && params[:jump_to_section].nil?) || (params[:action] == 'edit' && params[:form].nil?)
      get_variables_response = cmr_client.get_variables({ 'provider' => get_resource.provider_id, 'native_id' => get_resource.native_id }, token)

      existing_variable = get_variables_response.success? && get_variables_response.body['hits'] == 1
    else
      existing_variable = false
    end

    @json_form = UmmJsonForm.new(
      plural_published_resource_name,
      'umm-var-form.json',
      @schema,
      get_resource.draft,
      field_prefix: 'variable_draft/draft',
      draft_id: get_resource.id,
      'existing_variable' => existing_variable
    )
  end

  def set_preview
    @preview = UmmPreview.new(
      schema_type: published_resource_name,
      preview_filename: 'umm-var-preview.json',
      data: get_resource.draft,
      draft_id: get_resource.id
    )
  end

  def set_current_form
    @current_form = params[:form] || @json_form.forms.first.parsed_json['id']
  end

  def variable_draft_params
    # Allow for completely empty forms to be saved
    return {} unless params.key?(:variable_draft)

    # If the form isn't empty, only permit whitelisted attributes
    permitted = params.require(:variable_draft).permit(:draft_type).tap do |whitelisted|
      # Allows for any nested key within the draft hash
      whitelisted[:draft] = params[:variable_draft][:draft]
    end
    permitted.to_unsafe_h # need to understand what this is doing more, think related to nested parameters not permitted.
  end
end
