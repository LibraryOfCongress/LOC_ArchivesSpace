require_relative 'converters/accession_converter'

class AccessionConverter

  class << self
    alias_method :configure_orig, :configure

    def configure
      config = configure_orig
      config['accession_lccn'] = 'accession.lccn'
      config['accession_date_received_by_library'] = [date_flip, 'accession.date_received_by_library']
      config['accession_division_acquisition_date'] = [date_flip, 'accession.division_acquisition_date']
      config['accession_is_new'] = [normalize_boolean, 'accession.is_new']
      config
    end

  end
end
