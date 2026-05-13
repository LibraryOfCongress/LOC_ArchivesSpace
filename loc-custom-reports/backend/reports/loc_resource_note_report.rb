class LocResourceNoteReport < AbstractReport
  
  register_report({
    params: [
      ["note_type", "String", "Note type code to check for absence (e.g. otherfindaid, bioghist, scopecontent). Leave blank to default to 'Other Finding Aids'."]
    ]
  })

  DEFAULT_NOTE_TYPE = 'otherfindaid'.freeze

  SUPPORTED_NOTE_TYPES = {
    'otherfindaid'   => 'Other Finding Aids',
    'bioghist'       => 'Biographical / Historical',
    'scopecontent'   => 'Scope and Content',
    'accessrestrict' => 'Conditions Governing Access',
    'userestrict'    => 'Conditions Governing Use',
    'prefercite'     => 'Preferred Citation',
    'custodhist'     => 'Custodial History',
    'acqinfo'        => 'Immediate Source of Acquisition',
    'processinfo'    => 'Processing Information',
    'arrangement'    => 'Arrangement',
  }.freeze

  def query
    info[:note_type]  = note_type_label
    
    safe_note_pat = "%\"type\":\"#{selected_note_type}\"%"
    
    has_note_query = db[:note]
      .where(Sequel.~(resource_id: nil))
      .where(Sequel.like(:notes, safe_note_pat))
      .select(:resource_id)

    results = db[:resource]
      .where(repo_id: @repo_id)
      .exclude(id: has_note_query)
      .order(:title)
      .select(
        Sequel.as(:title, :title),
        Sequel.as(:ead_id, :ead_id)
      )

    info[:total_count] = results.count
    results
  end

  def fix_row(row)
    row[:title] ||= '(untitled)'
    row[:ead_id] ||= '(no EAD ID)'
  end

  def identifier_field
    :ead_id
  end

  private

  def selected_note_type
    val = @params&.fetch('note_type', nil) || @params&.fetch(:note_type, nil)
    val = val.to_s.strip
    return DEFAULT_NOTE_TYPE if val.empty?

    SUPPORTED_NOTE_TYPES.key?(val) ? val : DEFAULT_NOTE_TYPE
  end

  def note_type_label
    SUPPORTED_NOTE_TYPES.fetch(selected_note_type, selected_note_type)
  end
end