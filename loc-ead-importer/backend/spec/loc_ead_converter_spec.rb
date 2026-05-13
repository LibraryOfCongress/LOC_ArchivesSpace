# -*- coding: utf-8 -*-

require_relative 'loc_converter_spec_helper'

describe 'LOC EAD3 Converter' do
  def my_converter
    LocEADConverter
  end

  def get_fixture(fixture_file)
    File.expand_path("./fixtures/#{fixture_file}", File.dirname(__FILE__))
  end

  describe "Conversion of LOC EAD3 Test File: af022009" do

    def test_file
      get_fixture("af022009.xml")
    end

    before(:all) do
      Thread.current[:request_context] ||= {}
      FactoryBot.create(:repo)
      parsed = convert(test_file)
      @corps = parsed.select { |rec| rec['jsonmodel_type'] == 'agent_corporate_entity' }
      @families = parsed.select { |rec| rec['jsonmodel_type'] == 'agent_family' }
      @people = parsed.select { |rec| rec['jsonmodel_type'] == 'agent_person' }
      @subjects = parsed.select { |rec| rec['jsonmodel_type'] == 'subject' }
      @digital_objects = parsed.select { |rec| rec['jsonmodel_type'] == 'digital_object' }
      @top_containers = parsed.select { |rec| rec['jsonmodel_type'] == 'top_container' }
      @archival_objects = parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }
      @resource = parsed.select { |rec| rec['jsonmodel_type'] == 'resource' }.last
    end

    it "maps '<unitid>' correctly" do
      expect(@resource["id_0"]).to eq("AFC 2017/049")
    end

    # AS-320
    it "obtains the finding_aid_filing_title from the sidecar csv file" do
      expect(@resource['finding_aid_filing_title']).to eq "lamacchia, linda"
    end
  end

  describe "handling nested <bioghist> tags in ms997003" do

    def test_file
      get_fixture("ms997003.xml")
    end

    before(:all) do
      parsed = convert(test_file)
      @archival_objects = parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }
      @resource = parsed.select { |rec| rec['jsonmodel_type'] == 'resource' }.last
    end

    it "creates a single note with subnotes for each nested chronology" do
      bioghist_notes = @resource['notes'].select { |n| n['type'] == 'bioghist' }
      expect(bioghist_notes.length).to eq 1
      chron_notes = bioghist_notes.first['subnotes'].select {|h| h['jsonmodel_type'] == 'note_chronology' }
      expect(chron_notes.length).to eq 9
      expect(chron_notes.first['title']).to eq "Henry Breckinridge"

      text_notes = bioghist_notes.first['subnotes'].select {|n| n['jsonmodel_type'] == 'note_text' }
      expect(text_notes.length).to eq 2
      # verify correct label
      expect(bioghist_notes.first['label']).to eq "Biographical Notes and Chronological List"

      # verify that notes are in expected order.
      subnote_types = bioghist_notes.first['subnotes'].map {|n| n['jsonmodel_type'] }
      expect(subnote_types.first).to eq "note_text"
    end
  end

  describe "AS-337: Handling <head> tags with IDs" do

    def test_file
      get_fixture("ms011041.xml")
    end

    before(:all) do
      parsed = convert(test_file)
      @resource = parsed.select { |rec| rec['jsonmodel_type'] == 'resource' }.last
    end

    it "correctly processes a note containing a <head> with an ID" do
      related_note = @resource['notes'].find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil
      expect(related_note['label']).to eq("Related Material")
      expect(related_note['persistent_id']).to be_nil
    end

    it "removes a <ref> tag that targets an ignored <head> ID" do
      odd_note = @resource['notes'].find { |n| n['label'] == 'Additional Information' }
      subnote_content = odd_note['subnotes'][0]['content']

      expect(odd_note).not_to be_nil
      expect(subnote_content).to include("Also see related material.")
      expect(subnote_content).not_to include("<ref target=\"related\">")
    end
  end

  describe 'AS-328: Reel Container Handling' do

    context "when a container has a compound type including 'reel'" do
      def test_file
        get_fixture("as328_compound.xml")
      end

      before(:all) do
        Thread.current[:request_context] ||= {}
        FactoryBot.create(:repo)
        @parsed = convert(test_file)
        @top_containers = @parsed.select { |rec| rec['jsonmodel_type'] == 'top_container' }

        @archival_object = @parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }.first
      end

      it "creates two separate top containers" do
        expect(@top_containers.length).to eq(2)
      end

      it "creates a 'Box' top container and a 'Reel' top container" do
        box_container = @top_containers.find { |tc| tc['type'] == 'Box' }
        reel_container = @top_containers.find { |tc| tc['type'] == 'Reel' }

        expect(box_container).not_to be_nil
        expect(reel_container).not_to be_nil

        expect(box_container['indicator']).to eq('50')
        expect(reel_container['indicator']).to eq('1')
      end

      it "links the archival object to both top containers via separate instances" do
        expect(@archival_object['instances'].length).to eq(2)
      end
    end

    context "when a 'reel' container follows another container and has a range" do
      def test_file
        get_fixture("as328_sequential.xml")
      end

      before(:all) do
        Thread.current[:request_context] ||= {}
        FactoryBot.create(:repo)
        @parsed = convert(test_file)
        @top_containers = @parsed.select { |rec| rec['jsonmodel_type'] == 'top_container' }

        @archival_object = @parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }.first
      end

      it "creates three separate top containers for the box and the reel range" do
        expect(@top_containers.length).to eq(3)
      end

      it "creates one 'Box' and two 'Reel' top containers with correct indicators" do
        box_container = @top_containers.find { |tc| tc['type'].downcase == 'box' && tc['indicator'] == '1' }
        reel_1 = @top_containers.find { |tc| tc['type'] == 'Reel' && tc['indicator'] == '1' }
        reel_2 = @top_containers.find { |tc| tc['type'] == 'Reel' && tc['indicator'] == '2' }

        expect(box_container).not_to be_nil
        expect(reel_1).not_to be_nil
        expect(reel_2).not_to be_nil
      end

      it "links the archival object to all three top containers via separate instances" do
        expect(@archival_object['instances'].length).to eq(3)
      end
    end
  end

   describe "AS-293: Prepending case numbers to titles for legal collections" do
    def test_file
      get_fixture("as293_legal_collection.xml")
    end

    before(:all) do
      Thread.current[:request_context] ||= {}
      FactoryBot.create(:repo)
      @parsed = convert(test_file)
      @archival_objects = @parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }
    end

    it "correctly prepends a single case number to the title" do
      ao = @archival_objects.find { |a| a['title']&.include?('Wright v. Regan') }
      expect(ao['title']).to eq("80-1124: Wright v. Regan")
      expect(ao['component_id']).to be_nil
    end

    it "correctly prepends multiple case numbers to the title, preserving order" do
      ao = @archival_objects.find { |a| a['title']&.include?('Sample Case') }
      expect(ao['title']).to eq("81-534, 81-599: Sample Case with two numbers")
      expect(ao['component_id']).to be_nil
    end

    it "only prepends unitids without a label attribute" do
      ao = @archival_objects.find { |a| a['title']&.include?('Case with other unitid') }
      expect(ao['title']).to eq("82-123: Case with other unitid")
      expect(ao['component_id']).to be_nil
    end

    it "does not modify the title if the relevant unitid has a label" do
      ao = @archival_objects.find { |a| a['title']&.include?('Should not be changed') }
      expect(ao['title']).to eq("Should not be changed")
      # Verifies that unitids with labels are still processed by other logic
      expect(ao['component_id']).to eq("Some Label: ignore-me")
    end

    it "correctly formats the title when the original title is empty" do
      ao = @archival_objects.find { |a| a['title']&.start_with?('83-456') }
      expect(ao).not_to be_nil
      expect(ao['title']).to eq("83-456")
    end

    it "correctly formats the title when the unittitle tag is missing" do
      ao = @archival_objects.find { |a| a['title']&.start_with?('84-789') }
      expect(ao).not_to be_nil
      expect(ao['title']).to eq("84-789")
    end
  end

  describe 'AS-328 Edge Case Handling' do
    def test_file
      get_fixture("as328_edge_cases.xml")
    end

    before(:all) do
      Thread.current[:request_context] ||= {}
      FactoryBot.create(:repo)
      @parsed = convert(test_file)
      @top_containers = @parsed.select { |rec| rec['jsonmodel_type'] == 'top_container' }
      @archival_objects = @parsed.select { |rec| rec['jsonmodel_type'] == 'archival_object' }
    end

    context 'when a series has a box range and a child has a simple reel' do
      it 'correctly ignores the series range and creates only the reel container' do
        series_ao = @archival_objects.find { |ao| ao['title'] == 'Series with Ignored Range' }
        file_ao = @archival_objects.find { |ao| ao['title'] == 'Child File with Simple Reel' }

        # The series should have no container instances
        expect(series_ao['instances']).to be_empty

        # The child file should have one instance pointing to Reel 5
        expect(file_ao['instances'].length).to eq(1)
        reel_5_tc = @top_containers.find { |tc| tc['type'] == 'Reel' && tc['indicator'] == '5' }
        expect(reel_5_tc).not_to be_nil
        expect(file_ao['instances'][0]['sub_container']['top_container']['ref']).to eq(reel_5_tc['uri'])

        # No boxes from the 1-10 range should have been created
        box_tcs_from_range = @top_containers.select { |tc| tc['type'] == 'Box' && ('1'..'10').include?(tc['indicator']) }
        expect(box_tcs_from_range).to be_empty
      end
    end

    # Child with a compound type
    context 'when a series has a box range and a child has a compound box-reel' do
      it 'ignores the series range and splits the childs container correctly' do
        # Verify the top containers were created
        box_31_tc = @top_containers.find { |tc| tc['type'] == 'Box' && tc['indicator'] == '31' }
        reel_8_tc = @top_containers.find { |tc| tc['type'] == 'Reel' && tc['indicator'] == '8' }
        expect(box_31_tc).not_to be_nil
        expect(reel_8_tc).not_to be_nil

        # Verify they are linked to the same child AO
        file_ao = @archival_objects.find { |ao| ao['title'] == 'Child File with Compound Box-Reel' }
        expect(file_ao['instances'].length).to eq(2)

        # No boxes from the 22-30 range should have been created
        box_tcs_from_range = @top_containers.select { |tc| tc['type'] == 'Box' && ('22'..'30').include?(tc['indicator']) }
        expect(box_tcs_from_range).to be_empty
      end
    end

    # File-level ranges
    context 'when a file-level component has both a box range and a reel' do
      it 'expands the box range AND creates the reel container' do
        file_ao = @archival_objects.find { |ao| ao['title'] == 'File with Mixed Container Types' }

        # The file should have 3 instances: Box 32, Box 33, and Reel 9
        expect(file_ao['instances'].length).to eq(3)

        # Verify the top containers were created
        box_32_tc = @top_containers.find { |tc| tc['type'] == 'Box' && tc['indicator'] == '32' }
        box_33_tc = @top_containers.find { |tc| tc['type'] == 'Box' && tc['indicator'] == '33' }
        reel_9_tc = @top_containers.find { |tc| tc['type'] == 'Reel' && tc['indicator'] == '9' }
        expect(box_32_tc).not_to be_nil
        expect(box_33_tc).not_to be_nil
        expect(reel_9_tc).not_to be_nil
      end
    end
  end

  describe "AS-372: langmaterial with multiple scripts" do
    it "creates a record for each language/script combination" do
      xml = <<~LANGMATERIAL
        <langmaterial label="Language" encodinganalog="546">
          <languageset>
            <language encodinganalog="041" langcode="eng">English</language>
            <script scriptcode="Latn"/>
          </languageset>
          <languageset>
            <language encodinganalog="041" langcode="hin">Hindi</language>
            <language encodinganalog="041" langcode="kfk">Kinnauri</language>
            <language encodinganalog="041" langcode="san">Sanskrit</language>
            <script scriptcode="Latn"/>
            <script scriptcode="Deva"/>
          </languageset>
          <languageset>
            <language encodinganalog="041" langcode="bod">Tibetan</language>
            <script scriptcode="Tibt"/>
            <script scriptcode="Latn"/>
          </languageset>
        </langmaterial>
      LANGMATERIAL

      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource

        converter.run

        # Filter for the actual language/script records, excluding any note-only records
        lang_records = resource.lang_materials.select { |lm| lm['language_and_script'] }

        expect(lang_records.length).to eq(9)

        combinations = lang_records.map { |lm| lm['language_and_script'].to_h }

        # Assert that each expected combination is present
        expect(combinations).to include({'language' => 'eng', 'script' => 'Latn'})

        expect(combinations).to include({'language' => 'hin', 'script' => 'Latn'})
        expect(combinations).to include({'language' => 'hin', 'script' => 'Deva'})

        expect(combinations).to include({'language' => 'kfk', 'script' => 'Latn'})
        expect(combinations).to include({'language' => 'kfk', 'script' => 'Deva'})

        expect(combinations).to include({'language' => 'san', 'script' => 'Latn'})
        expect(combinations).to include({'language' => 'san', 'script' => 'Deva'})

        expect(combinations).to include({'language' => 'bod', 'script' => 'Tibt'})
        expect(combinations).to include({'language' => 'bod', 'script' => 'Latn'})
      end
    end
  end

  describe "AS-365: Mixed content in <langmaterial>" do

    it "correctly imports mixed <languageset> and standalone <language> tags" do
      xml = <<~EAD
        <archdesc>
          <did>
            <langmaterial>
              <languageset>
                <language langcode="mya">Burmese</language>
                <language langcode="eng">English</language>
                <script scriptcode="Latn"/>
              </languageset>
              <language langcode="ara">Arabic</language>
              <language langcode="yue">Cantonese</language>
              <descriptivenote>
                <p>Collection material in multiple languages.</p>
              </descriptivenote>
            </langmaterial>
          </did>
        </archdesc>
      EAD

      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run

        # Check for language/script records
        lang_script_records = resource.lang_materials.select { |lm| lm['language_and_script'] }
        expect(lang_script_records.length).to eq(4)

        combinations = lang_script_records.map { |lm| lm['language_and_script'] }
        expect(combinations).to include({ 'language' => 'mya', 'script' => 'Latn' }) # From languageset
        expect(combinations).to include({ 'language' => 'eng', 'script' => 'Latn' }) # From languageset
        expect(combinations).to include({ 'language' => 'ara', 'script' => nil })  # Standalone
        expect(combinations).to include({ 'language' => 'yue', 'script' => nil })  # Standalone

        # Check that the descriptive note is preserved
        note_record = resource.lang_materials.find { |lm| lm['notes'] && !lm['notes'].empty? }
        expect(note_record).not_to be_nil
        expect(note_record['notes'][0]['content'][0]).to include("Collection material in multiple languages.")
      end
    end

    it "handles a standalone <language> tag with its own scriptcode attribute" do
      xml = '<langmaterial><language langcode="rus" scriptcode="Cyrl">Russian</language></langmaterial>'
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        lang_script_records = resource.lang_materials.select { |lm| lm['language_and_script'] }
        expect(lang_script_records.length).to eq(1)
        expect(lang_script_records.first['language_and_script']).to eq({ 'language' => 'rus', 'script' => 'Cyrl' })
      end
    end

    it "falls back to 'eng' for an empty <langmaterial> tag" do
      xml = '<langmaterial></langmaterial>'
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        lang_script_records = resource.lang_materials.select { |lm| lm['language_and_script'] }
        expect(lang_script_records.length).to eq(1)
        expect(lang_script_records.first['language_and_script']).to eq({ 'language' => 'eng' })
      end
    end
  end

  describe 'AS-362: LCCN Note Handling' do

    def run_note_conversion(xml)
      full_xml = "<archdesc><did>#{xml}</did></archdesc>"
      resource = nil
      with_converter_instance(full_xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
      end
      resource.notes.first
    end

    context "when handling <otherfindaid> notes" do

      it "does not publish a note when audience is 'internal'" do
        xml = <<~EAD
          <otherfindaid audience="internal">
            <p>An internal note with an lccn link.</p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        expect(note['publish']).to be false
        expect(note['subnotes'][0]['publish']).to be false
      end

      it "correctly transforms a standard LCCN note from the ticket" do
        xml = <<~EAD
          <otherfindaid>
            <p>Catalog Record: <ref show="new" href="https://lccn.loc.gov/mm77034132">https://lccn.loc.gov/mm77034132</ref></p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        expect(note['type']).to eq('otherfindaid')
        expect(note['label']).to eq('Catalog Record')
        expect(note['subnotes'][0]['content']).not_to include('Catalog Record:')
        expect(note['subnotes'][0]['content']).to include('<ref show="new" href="https://lccn.loc.gov/mm77034132">')
      end

      it "is case-insensitive for 'lccn', 'LCCN', and the 'Catalog Record' prefix" do
        xml = <<~EAD
          <otherfindaid>
            <p>catalog record: <ref show="new" href="https://LCCN.loc.gov/12345">Link</ref></p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        expect(note['label']).to eq('Catalog Record')
        expect(note['subnotes'][0]['content']).not_to include('catalog record:')
      end

      it "strips the prefix with varied whitespace and without a colon" do
        xml = <<~EAD
          <otherfindaid>
            <p>  Catalog Record  <ref show="new" href="https://lccn.loc.gov/12345">Link</ref></p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        expect(note['label']).to eq('Catalog Record')
        # formatted content should start directly with the link
        expect(note['subnotes'][0]['content'].strip).to start_with('<ref')
      end

      it "does not affect <otherfindaid> notes that do not contain 'lccn'" do
        xml = <<~EAD
          <otherfindaid>
            <head>See Also</head>
            <p>Related materials are available elsewhere.</p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        expect(note['type']).to eq('otherfindaid')
        expect(note['label']).to eq('See Also')
        expect(note['subnotes'][0]['content']).to include('Related materials are available elsewhere.')
      end

      it "ensures the created LCCN note and its subnote are marked as published" do
        xml = '<otherfindaid><p>A brief lccn link</p></otherfindaid>'
        note = run_note_conversion(xml)

        expect(note['publish']).to be true
        expect(note['subnotes'][0]['publish']).to be true
      end
    end

    context "when handling <controlnote> notes" do

      it "does not affect a <controlnote label='otherNote'> if it lacks an LCCN" do
        xml = <<~EAD
          <controlnote label="otherNote">
            <p>This is some other kind of note, but not a catalog record link.</p>
          </controlnote>
        EAD
        note = run_note_conversion(xml)

        expect(note['type']).to eq('Control Note')
        expect(note['subnotes'][0]['content']).to include('other kind of note')
      end

      it "transforms a <controlnote label='otherNote'> with an LCCN into a catalog record note" do
        xml = <<~EAD
          <controlnote label="otherNote">
            <p>Catalog Record: <ref show="new" href="https://lccn.loc.gov/98765">Link</ref></p>
          </controlnote>
        EAD
        note = run_note_conversion(xml)

        # type becomes 'otherfindaid'
        expect(note['type']).to eq('otherfindaid')
        expect(note['label']).to eq('Catalog Record')
        expect(note['subnotes'][0]['content']).not_to include('Catalog Record:')
        expect(note['subnotes'][0]['content']).to include('<ref')
      end

      it "does not affect a regular <controlnote> even if it contains 'lccn'" do
        xml = <<~EAD
          <controlnote id="lccnNote">
            <p>An LCCN is present, but this is a standard control note without the 'otherNote' label.</p>
          </controlnote>
        EAD
        note = run_note_conversion(xml)

        expect(note['type']).to eq('Control Note')
        expect(note['label']).to be_nil
        expect(note['subnotes'][0]['content']).to include('standard control note')
      end

      it "does not affect a <controlnote label='otherNote'> if it lacks an LCCN" do
        xml = <<~EAD
          <controlnote label="otherNote">
            <p>This is some other kind of note, but not a catalog record link.</p>
          </controlnote>
        EAD
        note = run_note_conversion(xml)

        expect(note['type']).to eq('Control Note')
        expect(note['subnotes'][0]['content']).to include('other kind of note')
      end
    end

    context "when preventing data corruption (edge cases)" do

      it "does NOT strip 'Catalog Record:' from the middle of a note" do
        xml = <<~EAD
          <otherfindaid>
            <p>For more information, see the collection's main Catalog Record: <ref href="https://lccn.loc.gov/12345">Link</ref></p>
          </otherfindaid>
        EAD
        note = run_note_conversion(xml)

        # note contains "lccn", so it should get the "Catalog Record" label.
        expect(note['label']).to eq('Catalog Record')

        # Because the phrase is not a prefix, the anchored regex should not match,
        # and the content be preserved intact.
        expect(note['subnotes'][0]['content']).to include("see the collection's main Catalog Record:")
      end
    end
  end

  describe "AS-322: Unittitle Cleanup" do

    def convert_unittitle(xml_string)
      full_xml = "<archdesc><dsc><c level='file'>#{xml_string}</c></dsc></archdesc>"
      archival_object = nil
      with_converter_instance(full_xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        archival_object = records_in_working_file.find { |record| record['jsonmodel_type'] == 'archival_object' }
      end
      archival_object['title']
    end

    it "removes the leading comma and space left by a preceding date tag" do
      xml = '<unittitle><date>2004</date>, Patterson 4 atoms calculation</unittitle>'
      expect(convert_unittitle(xml)).to eq("Patterson 4 atoms calculation")
    end

    it "removes a single trailing comma" do
      xml = '<unittitle>My Important Title,</unittitle>'
      expect(convert_unittitle(xml)).to eq("My Important Title")
    end

    it "removes a trailing comma that comes before a single quote" do
      xml = "<unittitle>A Quoted Title,'</unittitle>"
      expect(convert_unittitle(xml)).to eq("A Quoted Title'")
    end

    it "removes a trailing comma that comes before a double quote" do
      xml = '<unittitle>Another Quoted Title,"</unittitle>'
      expect(convert_unittitle(xml)).to eq('Another Quoted Title"')
    end

    it "does not modify a title with no special leading or trailing characters" do
      xml = '<unittitle>A Perfectly Normal Title</unittitle>'
      expect(convert_unittitle(xml)).to eq("A Perfectly Normal Title")
    end

    it "does not remove commas from the middle of a title" do
      xml = '<unittitle>Title, with a comma, in the middle</unittitle>'
      expect(convert_unittitle(xml)).to eq("Title, with a comma, in the middle")
    end

    it "handles a title with text followed by multiple date tags" do
      xml = '<unittitle>Oversize, <date>1774-1784</date>, <date>1972</date>, <date>undated</date></unittitle>'
      expect(convert_unittitle(xml)).to eq("Oversize")
    end

    it "handles a title that starts with multiple date tags before the text" do
      xml = '<unittitle><date>2004</date>, <date>2005</date>, Real Title Content</unittitle>'
      expect(convert_unittitle(xml)).to eq("Real Title Content")
    end

    it "handles a title with surrounding dates and internal text" do
      xml = '<unittitle><date>2001</date>, Some Text, <date>2002</date></unittitle>'
      expect(convert_unittitle(xml)).to eq("Some Text")
    end

    it "handles inconsistent whitespace around commas and dates" do
      xml = '<unittitle>Messy Title ,<date>2001</date> ,  <date>2002</date>, and some more text,</unittitle>'
      expect(convert_unittitle(xml)).to eq("Messy Title, and some more text")
    end

    it "does not collapse legitimate internal commas within the title text" do
      xml = '<unittitle>First part, second part, <date>2000</date></unittitle>'
      expect(convert_unittitle(xml)).to eq("First part, second part")
    end

    # AS-452
    it "does not remove emph tags" do
      xml = '<unittitle><emph render="italic">The Death of Klinghoffer</emph>, <date localtype="inclusive" normal="1991">1991</date></unittitle>'
      expect(convert_unittitle(xml)).to eq("<emph render=\"italic\">The Death of Klinghoffer</emph>")
    end
  end


  describe "AS-395: Complicated Music Container Parsing" do

    def convert_and_get_results(container_string)
      xml = <<~EAD
        <ead>
          <archdesc level="collection">
            <did>
              <unittitle>Test Resource</unittitle>
              <unitid>test-id</unitid>
              <physdesc label="extent">1 box</physdesc>
              <langmaterial><language langcode="eng">English</language></langmaterial>
              <unitdate normal="2025-09-11">2025</unitdate>
            </did>
            <dsc>
              <c level="file">
                <did>
                  <unittitle>Test Case</unittitle>
                  <container localtype="box-folder">#{container_string}</container>
                </did>
              </c>
            </dsc>
          </archdesc>
        </ead>
      EAD

      top_containers = []
      archival_object = nil
      with_converter_instance(xml) do |converter, batch, records|
        converter.run
        top_containers = records.select { |r| r['jsonmodel_type'] == 'top_container' }
        archival_object = records.select { |r| r['jsonmodel_type'] == 'archival_object' }.first
      end
      return top_containers, archival_object
    end

    context "with the primary example from the ticket" do
      before(:all) do
        @top_containers, @archival_object = convert_and_get_results("143/1, 306/1 to 307/27, 368/2 to 372/2-8, 435/2")
      end

      def get_instance_for_box(box_indicator)
        instance = @archival_object['instances'].find do |i|
          tc = @top_containers.find { |t| t['uri'] == i['sub_container']['top_container']['ref'] }
          tc && tc['indicator'] == box_indicator
        end
        expect(instance).not_to be_nil, "Instance for Box '#{box_indicator}' not found"
        instance['sub_container']
      end

      it "creates the correct number of top containers and instances" do
        # Should create a TC for boxes 143, 306, 307, 368, 369, 370, 371, 372, 435
        expect(@top_containers.length).to eq(9)
        expect(@archival_object['instances'].length).to eq(9)
      end

      it "parses simple part '143/1' to create a folder" do
        sub_container = get_instance_for_box('143')
        expect(sub_container['type_2']).to eq('folder')
        expect(sub_container['indicator_2']).to eq('1')
      end

      it "parses the start of a range '306/1 to ...' with no sub-container" do
        sub_container = get_instance_for_box('306')
        expect(sub_container['type_2']).to be_nil
        expect(sub_container['indicator_2']).to be_nil
      end

      it "parses the end of a range '... to 307/27' as a 1-N folder range" do
        sub_container = get_instance_for_box('307')
        expect(sub_container['type_2']).to eq('folder')
        expect(sub_container['indicator_2']).to eq('1-27')
      end

      it "parses the start of a range '368/2 to ...' as an N-* folder string" do
        sub_container = get_instance_for_box('368')
        expect(sub_container['type_2']).to eq('folder')
        expect(sub_container['indicator_2']).to eq('2-*')
      end

      it "creates placeholder containers for the gap between 368 and 372" do
        ['369', '370', '371'].each do |indicator|
          sub_container = get_instance_for_box(indicator)
          expect(sub_container['type_2']).to be_nil
          expect(sub_container['indicator_2']).to be_nil
        end
      end

      it "parses the end of a range '... to 372/2-8' as a literal folder range" do
        sub_container = get_instance_for_box('372')
        expect(sub_container['type_2']).to eq('folder')
        expect(sub_container['indicator_2']).to eq('2-8')
      end

      it "parses the final simple part '435/2' to create a folder" do
        sub_container = get_instance_for_box('435')
        expect(sub_container['type_2']).to eq('folder')
        expect(sub_container['indicator_2']).to eq('2')
      end
    end

    context "when handling variations and edge cases" do
      it "does NOT fill gaps in a statement that does not contain 'to'" do
        tcs, ao = convert_and_get_results("306/1, 309/5")
        expect(tcs.length).to eq(2) # Should only create 306 and 309
        expect(ao['instances'].length).to eq(2)
        tc_indicators = tcs.map { |tc| tc['indicator'] }.sort
        expect(tc_indicators).to eq(['306', '309'])
      end

      it "handles consecutive 'to' ranges correctly without creating extra containers" do
        tcs, ao = convert_and_get_results("306/2-5 to 307/1-5")
        expect(tcs.length).to eq(2)
        expect(ao['instances'].length).to eq(2)
        expect(tcs.map { |tc| tc['indicator'] }.sort).to eq(['306', '307'])
      end

      it "handles non-numeric prefixes and does NOT gap-fill across commas" do
        tcs, ao = convert_and_get_results("OV 10/2 to OV 12/5, OV 15/1")
        expect(tcs.length).to eq(4) # OV 10, OV 11, OV 12, and OV 15. NO gap-fill to 13, 14.
        expect(ao['instances'].length).to eq(4)
        tc_indicators = tcs.map { |tc| tc['indicator'] }.sort
        expect(tc_indicators).to eq(['OV 10', 'OV 11', 'OV 12', 'OV 15'])
      end

      it "does not fill gaps if box prefixes are different" do
        tcs, ao = convert_and_get_results("Box 10/1, OV 12/1")
        expect(tcs.length).to eq(2)
        expect(tcs.map { |tc| tc['indicator'] }.sort).to eq(['Box 10', 'OV 12'])
      end

      it "does not fill gaps for non-standard indicators that cannot be compared" do
        tcs, _ = convert_and_get_results("10A/1, 10C/1")
        expect(tcs.length).to eq(2)
        expect(tcs.map { |tc| tc['indicator'] }.sort).to eq(['10A', '10C'])
      end

      it "correctly parses a simple part that is only a box number" do
        tcs, ao = convert_and_get_results("306, 307/5")
        instance = ao['instances'].find do |i|
          tc = tcs.find { |t| t['uri'] == i['sub_container']['top_container']['ref'] }
          tc && tc['indicator'] == '306'
        end
        expect(instance['sub_container']['type_2']).to be_nil
      end

      it "correctly parses a range ending in '/1'" do
        tcs, ao = convert_and_get_results("306/2 to 307/1")
        instance = ao['instances'].find do |i|
          tc = tcs.find { |t| t['uri'] == i['sub_container']['top_container']['ref'] }
          tc && tc['indicator'] == '307'
        end
        expect(instance['sub_container']['indicator_2']).to eq('1')
      end

      it "handles a single complex range as the only content" do
        tcs, ao = convert_and_get_results("OV 100/2 to OV 102/5")
        expect(tcs.length).to eq(3) # OV 100, OV 101, OV 102
        expect(ao['instances'].length).to eq(3)
        tc_indicators = tcs.map { |tc| tc['indicator'] }.sort
        expect(tc_indicators).to eq(['OV 100', 'OV 101', 'OV 102'])
      end
    end
  end

  describe "AS-396: On-site access note for digital objects" do

    def convert_and_get_digital_object(xml_did_content)
      full_xml = "<archdesc><dsc><c level='file'><did>#{xml_did_content}</did></c></dsc></archdesc>"
      digital_object = nil
      with_converter_instance(full_xml) do |converter, batch, records|
        batch << ASpaceImport::JSONModel(:resource).new
        converter.run
        digital_object = records.find { |r| r.jsonmodel_type == 'digital_object' }
      end
      digital_object
    end

    let(:expected_note_text) { "Access to this digital content is available onsite only and requires advance request. Consult reference staff for more information." }

    context "when a DAO is created from a <unitid>" do
      it "adds the note for a 'Digital ID' unitid" do
        xml = '<unittitle>Test</unittitle><unitid label="Digital ID">digid123</unitid>'
        digital_object = convert_and_get_digital_object(xml)

        access_note = digital_object.notes.find { |n| n['type'] == 'accessrestrict' }
        expect(access_note).not_to be_nil
        expect(access_note['content']).to include(expected_note_text)
        expect(access_note['label']).to eq('Conditions Governing Access')
      end

      it "adds the note for a 'Filename' unitid" do
        xml = '<unittitle>Test</unittitle><unitid label="Filename">/path/to/file.tif</unitid>'
        digital_object = convert_and_get_digital_object(xml)

        access_note = digital_object.notes.find { |n| n['type'] == 'accessrestrict' }
        expect(access_note).not_to be_nil
        expect(access_note['content']).to include(expected_note_text)
      end
    end

    context "when a DAO is created from a <dao> tag" do
      it "adds the note for a DAO with daotype='borndigital'" do
        xml = '<unittitle>Test</unittitle><dao daotype="borndigital" href="/another/path/file.pdf"></dao>'
        digital_object = convert_and_get_digital_object(xml)

        access_note = digital_object.notes.find { |n| n['type'] == 'accessrestrict' }
        expect(access_note).not_to be_nil
        expect(access_note['content']).to include(expected_note_text)
      end

      it "adds the note for a DAO with a file URI that is not a web link" do
        xml = '<unittitle>Test</unittitle><dao href="Z:/share/digital/file.mov"></dao>'
        digital_object = convert_and_get_digital_object(xml)

        access_note = digital_object.notes.find { |n| n['type'] == 'accessrestrict' }
        expect(access_note).not_to be_nil
        expect(access_note['content']).to include(expected_note_text)
      end

      it "does NOT add the note for a standard web-accessible DAO" do
        xml = '<unittitle>Test</unittitle><dao href="https://hdl.loc.gov/12345"></dao>'
        digital_object = convert_and_get_digital_object(xml)

        access_note = digital_object.notes.find { |n| n['type'] == 'accessrestrict' }
        expect(access_note).to be_nil
      end
    end
  end

  # AS-402: Move "See also" links from <unittitle> to a Related Materials note
  describe "AS-402: <unittitle> 'See also' link handling" do

    def convert_and_get_ao(xml_did_content)
      full_xml = "<archdesc><dsc><c level='file'>#{xml_did_content}</c></dsc></archdesc>"
      archival_object = nil
      with_converter_instance(full_xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        archival_object = records_in_working_file.find { |record| record['jsonmodel_type'] == 'archival_object' }
      end
      archival_object
    end

    it "moves a <ref> tag with 'See also' from <unittitle> to a new Related Materials note" do
      xml = <<~EAD
        <did>
          <unittitle id="con1calvcoff">
            Califano v. Coffin
            <ref target="con30calvcoff">
              <emph render="italic"> See also Container 30, same heading </emph>
            </ref>
          </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      # Check that the title is cleaned
      expect(ao.title.strip).to eq("Califano v. Coffin")

      # Check that a 'relatedmaterial' note was created
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil

      # Check that the note contains the original, full <ref> tag
      subnote_content = related_note['subnotes'][0]['content']
      expect(subnote_content).to include('<ref target="con30calvcoff">')
      expect(subnote_content).to include('<emph render="italic"> See also Container 30, same heading </emph>')
      expect(subnote_content).to include('</ref>')
    end

    it "does NOT move a <ref> tag that does not contain 'See also'" do
      xml = <<~EAD
        <did>
          <unittitle encodinganalog="245$a">
            <ref target="rest">*</ref> 1966-1992
          </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      # Check that the title still contains the ref content
      expect(ao.title).to include('<ref target="rest">*</ref> 1966-1992')

      # Check that no 'relatedmaterial' note was created
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).to be_nil
    end

    it "moves a <ref> tag with case-insensitive 'see also' text" do
      xml = <<~EAD
        <did>
          <unittitle>
            Main Title
            <ref target="some_target"> see also some other item </ref>
          </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      expect(ao.title.strip).to eq("Main Title")
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil
      expect(related_note['subnotes'][0]['content']).to include('see also some other item')
    end

    it "moves only the correct <ref> tag when multiple are present in one unittitle" do
      xml = <<~EAD
        <did>
          <unittitle>
            <ref target="dontmove">*</ref> Complex Title
            <ref target="moveme"> (See also another item) </ref>
            with extra text
          </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      expect(ao.title.strip).to eq("<ref target=\"dontmove\">*</ref> Complex Title with extra text")
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil
      expect(related_note['subnotes'][0]['content']).to include('(See also another item)')
    end

    it "appends the <ref> content to an existing Related Materials note" do
      xml = <<~EAD
        <did>
          <unittitle>
            Existing Note Test
            <ref target="moveme"> See also the new item </ref>
          </unittitle>
        </did>
        <relatedmaterial>
          <head>Related Material</head>
          <p>This is a pre-existing related materials note.</p>
        </relatedmaterial>
      EAD
      ao = convert_and_get_ao(xml)

      # Check that there is only one related material note
      related_notes = ao.notes.select { |n| n['type'] == 'relatedmaterial' }
      expect(related_notes.length).to eq(1)

      # Check that the note has two subnotes: the original and the new one
      all_subnotes = related_notes[0]['subnotes']
      expect(all_subnotes.length).to eq(2)

      # Check their content
      expect(all_subnotes[0]['content']).to include("This is a pre-existing related materials note.")
      expect(all_subnotes[1]['content']).to include("<ref target=\"moveme\"> See also the new item </ref>")
    end


    it "moves a <ref> tag with 'See same container' from <unittitle> to a new Related Materials note" do
      xml = <<~EAD
        <did>
           <unitid>80-15</unitid>
           <unittitle encodinganalog="245$a">Amoco Prod. Co. v. Jicarilla Apache
  Tribe <ref target="cont3">
                 <emph render="italic">See same container,</emph> 80-11</ref>
           </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      # Check that the title is cleaned
      expect(ao.title).to eq("Amoco Prod. Co. v. Jicarilla Apache Tribe")

      # Check that a 'relatedmaterial' note was created
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil

      # Check that the note contains the original, full <ref> tag
      subnote_content = related_note['subnotes'][0]['content']
      expect(subnote_content).to eq('<ref target="cont3"> <emph render="italic">See same container,</emph> 80-11</ref>')
    end

    it "moves a multiple <ref> tags with 'See same container' from <unittitle> to a new Related Materials note" do
      xml = <<~EAD
        <did>
           <unitid>84-604</unitid>
           <unittitle encodinganalog="245$a">Joel v. Cirrito <ref target="cont110">
                 <emph render="italic">See same container,</emph> 84-648</ref>, and
     <ref target="cont111">
                 <emph render="italic">Container I:163</emph>, 84-822</ref>
           </unittitle>
        </did>
      EAD
      ao = convert_and_get_ao(xml)

      # Check that the title is cleaned
      expect(ao.title).to eq("Joel v. Cirrito")

      # Check that a 'relatedmaterial' note was created
      related_note = ao.notes.find { |n| n['type'] == 'relatedmaterial' }
      expect(related_note).not_to be_nil

      # Check that the note contains the original, full <ref> tag
      subnote_content = related_note['subnotes'][0]['content']
      expect(subnote_content).to eq('<ref target="cont110"> <emph render="italic">See same container,</emph> 84-648</ref>, and <ref target="cont111"> <emph render="italic">Container I:163</emph>, 84-822</ref>')
    end
  end
end
