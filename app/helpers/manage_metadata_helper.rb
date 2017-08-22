# :nodoc:
module ManageMetadataHelper
  def breadcrumb_name(metadata, type)
    short_name = if type.downcase.include? 'collection'
                   metadata['ShortName'] || '<Blank Short Name>'
                 elsif type.downcase.include? 'variable'
                   metadata['Name'] || '<Blank Name>'
                 end

    version = metadata.fetch('Version', '')
    version = "_#{version}" unless version.empty?

    short_name + version
  end

  # the resource type for the Search button text based on the controller
  def resource_type
    case
    when controller_name.include?('search')
      @record_type
    when controller_name.include?('collection')
      'collections'
    when controller_name.include?('variable')
      'variables'
    else
      # default
      'collections'
    end
  end

  def display_header_subtitle(metadata, type)
    if type.downcase.include? 'variable'
      metadata['LongName'] || 'Long Name Not Provided'
    else
      # Future services name
    end
  end
end
