module PiqToDraft
  KEYS = {
    collection_info: [:title, :version],
    data_info: [:quality_assurance],
    temporal_extent: [:start_date],
    spatial_extent: [:bounding_box_north, :bounding_box_south, :bounding_box_east, :bounding_box_west],
    author: [:name, :email]
  }

  def self.valid?(params)
    valid = true
    KEYS.except(:contact).each do |key, values|
      valid &= params[key].present?
      break if !valid
      values.each do |sub_key|
        valid &= params[key][sub_key].present?
      end
    end
  end

  def self.convert(data)
    person = data[:author]
    collection_info = data[:collection_info]
    dataset = data[:dataset]
    rawScienceKeywords = JSON.parse(data[:keyword][:science_keywords])
    scienceKeywords = []
    rawScienceKeywords.each do |keyword|
      updatedKeyword = keyword.slice('Category', 'Topic', 'Term', 'VariableLevel1', 'VariableLevel2', 'VariableLevel3')
      scienceKeywords.push(updatedKeyword)
    end

    col = {
      ShortName: collection_info[:short_title] || collection_info[:title][0..50].gsub(' ', '_').downcase,
      Version: collection_info[:version],
      VersionDescription: collection_info[:version_description],
      EntryTitle: collection_info[:title],
      DOI: {
        DOI: collection_info[:doi] != 'N/A'
      },
      Abstract: collection_info[:abstract] || 'N/A',
      ProcessingLevel: {
        Id: dataset[:other_processing_level].present? ? 'NA' : dataset[:nasa_processing_level],
        ProcessingLevelDescription: dataset[:other_processing_level]
      },
      Quality: data[:data_info][:quality_assurance],
      UseConstraints: {
        Description: {
          Description: dataset[:constraints]
        }
      },
      AccessConstraints: {
        Description: dataset[:public],
        # Allows the author to constrain access to the collection. This includes
        # any special restrictions, legal prerequisites, limitations and/or
        # warnings on obtaining collection data. Some words that may be used in
        # this element's value include: Public, In-house, Limited, None. The
        # value field is used for special ACL rules (Access Control Lists
        # (http://en.wikipedia.org/wiki/Access_control_list)). For example it
        # can be used to hide metadata when it isn't ready for public
        # consumption.
        Value: dataset[:public] === 'Yes, this data is freely available to the public' ? 0 : 1
      },
      TemporalExtents: [
        EndsAtPresentFlag: data[:temporal_extent][:ongoing],
        SingleDateTimes: [data[:temporal_extent][:start_date], data[:temporal_extent][:end_date]]
      ],
      # Is this correct?
      EndsAtPresentFlag: data[:temporal_extent][:ongoing],
      SpatialExtent: {
        SpatialCoverageType: 'HORIZONTAL',
        GranuleSpatialRepresentation: 'CARTESIAN',
        HorizontalSpatialDomain: {
          Geometry: {
            BoundingRectangles: [{
              NorthBoundingCoordinate: data[:spatial_extent][:bounding_box_north],
              SouthBoundingCoordinate: data[:spatial_extent][:bounding_box_south],
              EastBoundingCoordinate: data[:spatial_extent][:bounding_box_east],
              WestBoundingCoordinate: data[:spatial_extent][:bounding_box_west]
            }],
            CoordinateSystem: 'CARTESIAN'
          }
        }
      },
      ContactPersons: [{
        Type: 'NonDataCenterContactPerson',
        FirstName: person[:name].split(' ')[0],
        LastName: person[:name].split(' ')[1],
        ContactInformation: {
          ContactMechanisms: [{
            Type: 'Email',
            Value: person[:email]
          }]
        },
        Roles: ['Investigator']
      }],
      Platforms: [{'Type': 'NOT APPLICABLE', ShortName: 'NOT APPLICABLE'}],
      ScienceKeywords: scienceKeywords,
      DataCenters: [{
        Roles: ['ORIGINATOR'],
        ShortName: 'MAAP Data Management Team',
        LongName: 'Multi-Mission Algorithm and Analysis Platform Data Management Team',
        ContactInformation: {
          RelatedUrls: [{
            URLContentType: 'DataCenterURL',
            Type: 'HOME PAGE',
            URL: 'https://www.maap-project.org'
          }]
        }
      }],
      CollectionProgress: 'COMPLETE',
      AdditionalAttributes: [{
        Name: 'Dataset Status',
        Description: 'MAAP data product status',
        Value: 'MAAP User-Shared Data Product',
        DataType: 'STRING'
      }, {
        Name: 'Data Format',
        Description: 'File format of the associated granules',
        DataType: 'STRING'
      }]
    }

    col
  end
end
