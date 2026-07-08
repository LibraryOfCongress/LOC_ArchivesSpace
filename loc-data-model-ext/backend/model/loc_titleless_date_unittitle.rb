# Emits a <unittitle> built from date information when an archival object has no
# title, so every AO has a <unittitle> (AS-546)
class LocTitlelessDateUnittitle
  def call(data, xml, fragments, context)
    return unless context == :did
    return unless blank?(data.title)

    text = date_as_title(Array(data.dates).first)
    return if blank?(text)

    xml.unittitle { xml.text(text) }
  end

  private

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  # Normalized first (begin, with -end if present), expression as fallback.
  def date_as_title(date)
    return nil unless date.is_a?(Hash)

    if !blank?(date['begin'])
      if !blank?(date['end']) && date['end'] != date['begin']
        "#{date['begin']}-#{date['end']}"
      else
        date['begin']
      end
    elsif !blank?(date['expression'])
      date['expression']
    end
  end
end