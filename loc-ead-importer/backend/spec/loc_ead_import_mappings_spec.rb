# -*- coding: utf-8 -*-

require_relative 'loc_converter_spec_helper'

describe 'LOC EAD3 Import Mappings' do

  describe "<physdesc> tag handler" do

    # There appear to be many variations of this example, where a number
    # and type appear in a larger string. We probably want to find a reasonable
    # balance between capturing structured information vs adding bad values to
    # the extent_type enumeration. (Any values not present in the list will be
    # added as a side effect of import).
    it "converts '<physdesc label=\"WHATEVER\">' to an `extent` subrecord" do
      xml  = <<~PHYSDESC
        <physdesc label="WHATEVER" encodinganalog="300">
          approximately 5,302 items
        </physdesc>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        # Seed the converter with a resource record that would be created
        # by top-level <ead> data:
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        # Now run the converter and assert extent data is correct:
        converter.run
        extent = resource.extents[0]
        expect(extent.number).to eq "5,302"
        expect(extent.extent_type).to eq("items")
        expect(extent.container_summary).to eq("approximately")
      end
    end

    it "meets AS-250 requirements" do
      xml = <<~PHYSDESC
      <physdesc label="Extent (Graphic Images)">
      20 photographic prints: black and white, color; various sizes </physdesc>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        extent = resource.extents[0]
        expect(extent.number).to eq "20"
        expect(extent.extent_type).to eq("photographic prints")
        expect(extent.physical_details).to eq("black and white, color")
        expect(extent.physical_description).to eq("Extent (Graphic Images): 20 photographic prints: black and white, color; various sizes")
      end
    end

    it "can handle cases where there is no number in the text" do
      xml = <<~PHYSDESC
     <physdesc encodinganalog="300">Piano-vocal scores; lead sheet; lyric sheets</physdesc>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        extent = resource.extents[0]
        expect(extent.number).to eq "0"
        expect(extent.extent_type).to eq("unknown")
        expect(extent.physical_details).to be_nil
        expect(extent.physical_description).to eq("Piano-vocal scores; lead sheet; lyric sheets")
      end
    end

    it "won't make extent records for archival objects in any repository" do
      xml = <<~XML
          <root>
             <physdesc encodinganalog="300">10 things</physdesc>
             <c02 id="mferd13e492" level="item">
                <did>
                   <unittitle>Collection Finding Aid</unittitle>
                   <physdesc encodinganalog="300">1 thing</physdesc>
                </did>
             </c02>
          </root>
           XML

      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        child_object = records_in_working_file[0]
        expect(resource.extents.size).to eq 1
        expect(child_object.extents.size).to eq 0
      end
    end

    # AS-307
    it "creates multiple extent records for strings with AND and PLUS" do
      xml = <<~PHYSDESC
     <physdesc encodinganalog="300">12 boxes plus 34 microfilm reels and 3 oversize</physdesc>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        expect(resource.extents.size).to eq 3
        expect(resource.extents[0].number).to eq "12"
        expect(resource.extents[0].extent_type).to eq("boxes")
        expect(resource.extents[1].number).to eq "34"
        expect(resource.extents[1].extent_type).to eq("microfilm reels")
        expect(resource.extents[2].number).to eq "3"
        expect(resource.extents[2].extent_type).to eq("oversize")
      end
    end

    # AS-339
    it "can parse extent types with parenthesis" do
      xml = <<~PHYSDESC
     <physdesc label="Extent">701 items (chiefly photographic prints); 57 x 41 cm. or smaller.</physdesc>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        extent = resource.extents[0]
        expect(extent.number).to eq "701"
        expect(extent.extent_type).to eq("items")
        expect(extent.physical_details).to eq("chiefly photographic prints")
        expect(extent.dimensions).to eq("57 x 41 cm. or smaller.")
        expect(extent.physical_description).to eq("Extent: 701 items (chiefly photographic prints); 57 x 41 cm. or smaller.")
      end
    end

    # AS-358
    it "combines the label and the tag content to populate the physical_description field" do
      xml = <<~PHYSDESC
      <foo>
        <physdesc label="Extent (military papers)" encodinganalog="300">3 items</physdesc>
      </foo>
      PHYSDESC
      with_converter_instance(xml) do |converter, batch|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        extent = resource.extents[0]
        expect(extent.number).to eq "3"
        expect(extent.extent_type).to eq("items")
        expect(extent.physical_description).to eq("Extent (military papers): 3 items")
      end
    end
  end

  describe "<unitdate> tag handler" do

    # Test for handling reversed historical date ranges.
    context "when begin date is after end date" do
      it "corrects the order of begin and end dates for any valid historical range" do
        xml = <<~UNITDATE
          <unitdate label="Incorrect Order" unitdatetype="inclusive" normal="2025/1500"
                    encodinganalog="245$f"
                    datechar="creation">2025-1500</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource

          converter.run
          date = resource.dates[0]

          # Verify that the handler reorders the dates
          expect(date.begin).to eq("1500")
          expect(date.end).to eq("2025")
        end
      end
    end

    # Test to validate proper conversion of a well-formed <unitdate>.
    context "when <unitdate> is well-formed" do
      it "correctly converts <unitdate> to a date subrecord" do
        xml = <<~UNITDATE
          <unitdate label="Well-formed Date" unitdatetype="inclusive" normal="1900/1950"
                    encodinganalog="245$f"
                    datechar="creation">1900-1950</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource

          converter.run
          date = resource.dates[0]

          # Verify the dates are correctly set
          expect(date.begin).to eq("1900")
          expect(date.end).to eq("1950")
          expect(date.label).to eq("creation")
          expect(date.date_type).to eq("inclusive")
          expect(date.expression).to eq("1900-1950")
        end
      end

      # AS-94
      it "correctly converts dates in YYYY-MM-DD format" do
        xml = <<~UNITDATE
          <unitdate label="Well-formed Date" unitdatetype="inclusive" normal="1900-02-12/1950-02-13"
                    encodinganalog="245$f"
                    datechar="creation">1900-1950</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource

          converter.run
          date = resource.dates[0]

          # Verify the dates are correctly set
          expect(date.begin).to eq("1900-02-12")
          expect(date.end).to eq("1950-02-13")
          expect(date.label).to eq("creation")
          expect(date.date_type).to eq("inclusive")
          expect(date.expression).to eq("1900-1950")
        end
      end
    end

    context "when <unitdate> is not well-formed" do
      it "correctly converts dates in YYYY-MM-DD format" do
        xml = <<~UNITDATE
          <unitdate label="Well-formed Date" unitdatetype="inclusive" normal="1900-02-12/19500213"
                    encodinganalog="245$f"
                    datechar="creation">1900-1950</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource

          converter.run
          date = resource.dates[0]

          # Verify the dates are correctly set
          expect(date.begin).to eq("1900-02-12")
          expect(date.end).to eq("1950-02-13")
          expect(date.label).to eq("creation")
          expect(date.date_type).to eq("inclusive")
          expect(date.expression).to eq("1900-1950")
        end
      end
    end

    context "unittitle contains only a nested unitdate" do
      # AS-333
      it "should not assign a title to the archival object" do
        # from mss/2000/ms000011.xml
        xml = <<~EAD
                <c05 id="mferd82e1127" level="file">
                   <did>
                      <unittitle encodinganalog="245$a">
                         <date>1862-1866 </date>
                      </unittitle>
                      <unitdate encodinganalog="245$f" unitdatetype="inclusive">1862-1866
                      </unitdate>
                   </did>
                </c05>
                EAD
        with_converter_instance(xml) do |converter, batch, closed_records|
          record = ASpaceImport::JSONModel(:resource).new
          batch << record
          converter.run
          archival_object = closed_records[0]
          expect(archival_object.title).to be_nil
          expect(archival_object.dates[0].expression).to eq "1862-1866"
        end
      end
    end

    # Test for converting <unitdate> with only a single date.
    context "when <unitdate> lacks an end date" do
      it "creates a date subrecord with only a begin date" do
        xml = <<~UNITDATE
          <unitdate label="Single Year" unitdatetype="single" normal="1850"
                    encodinganalog="245$f"
                    datechar="creation">1850</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource

          converter.run
          date = resource.dates[0]

          # Verify the date is created with only a begin date
          expect(date.begin).to eq("1850")
          expect(date.end).to be_nil
          expect(date.label).to eq("creation")
          expect(date.date_type).to eq("inclusive")
          expect(date.expression).to eq("1850")
        end
      end
    end

    # 415
    context "when <unitdate> lacks the @normal attribute" do
      it "can still parse inclusive dates" do
        xml = <<~UNITDATE
          <unitdate encodinganalog="245$f" era="ce" calendar="gregorian">1903-1909</unitdate>
        UNITDATE

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          date = resource.dates[0]
          expect(date.begin).to eq("1903")
          expect(date.end).to eq("1909")
          expect(date.label).to eq("creation")
          expect(date.date_type).to eq("inclusive")
          expect(date.expression).to eq("1903-1909")
        end
      end
    end
  end

  describe "date handling" do
    # AS-280
    it "can correct an invalid date" do
      xml = <<~EAD
              <c04 id="mferd38e17151" level="file">
                 <did>
                    <container localtype="box">358</container>
                    <unittitle id="utid40834" encodinganalog="245$a">
                       <date localtype="inclusive" normal="2005-11-31">2005, Nov.
                        31</date>, 4 atom</unittitle>
                    <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="2005-11-31">2005, Nov. 31</unitdate>
                 </did>
              </c04>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
        batch << resource
          expect { converter.run }.not_to raise_error
          archival_object = records_in_working_file.select {|r| r.jsonmodel_type == "archival_object" }.first
          expect(archival_object.dates[0].begin).to eq "2005-11-30"
      end
    end
  end

  describe "setting resource.id_0 " do
    context "when there is no <unitid> but there is a <controlnote>" do
      it "sets resource.id_0 from the <controlnote>" do
        xml = <<~EAD
        <not_ead>
          <control>
             <filedesc>
                <notestmt>
                 <controlnote id="lccnNote">
               <p>Catalog Record: <ref show="new" actuate="onrequest" href="https://lccn.loc.gov/2020603131">https://lccn.loc.gov/2020603131</ref>
               </p>
                 </controlnote>
             </notestmt>
           </filedesc>
         </control>
       </not_ead>
       EAD

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          expect(resource.id_0).to eq("2020603131")
        end
      end
    end

    context "when there is a <unitid> and also a <controlnote>" do
      it "sets resource.id_0 from the <unitid>" do
        xml = <<~EAD
        <not_ead>
          <control>
             <filedesc>
                <notestmt>
                 <controlnote id="lccnNote">
               <p>Catalog Record: <ref show="new" actuate="onrequest" href="https://lccn.loc.gov/2020603131">https://lccn.loc.gov/2020603131</ref>
               </p>
                 </controlnote>
             </notestmt>
           </filedesc>
         </control>
         <archdesc>
           <did>
             <unitid>HELLO</unitid>
           </did>
         </archdesc>
       </not_ead>
       EAD

        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          expect(resource.id_0).to eq("HELLO")
        end
      end
    end

    # AS-220
    describe "<unitid> handling" do
      context "<unitid> within a <cX> tag" do
        it "populates the component_id with the unitid prefixed by the unitid/@label attribute" do
          xml = <<~EAD
                <unitid label="ID No." encodinganalog="590" countrycode="US" repositorycode="US-DLC">MSS84430</unitid>
                 EAD
          with_converter_instance(xml) do |converter, batch|
            batch << ASpaceImport::JSONModel(:resource).new
            archival_object = ASpaceImport::JSONModel(:archival_object).new
            batch << archival_object
            converter.run
            expect(archival_object.component_id).to eq("Item ID: MSS84430")
          end
        end
      end

      context "<unitid> within a <archdesc> tag" do
        it "does not prefix the id_0 values with the unitid/@label attribute" do
          xml = <<~EAD
                <unitid label="ID No." encodinganalog="590" countrycode="US" repositorycode="US-DLC">MSS84430</unitid>
                 EAD
          with_converter_instance(xml) do |converter, batch|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            expect(record.id_0).to eq("MSS84430")
          end
        end
      end

      context "label indicates LCCN" do

        # AS-273
        it "if the unitid contains ref tags, take the first one for component_id and make an odd note" do
          # example from music/2012/mu12007.xml
          xml = <<~EAD
                 <c03 id="mferd92e5248" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Episode #29, <date>1964, April 8</date>
                       </unittitle>
                       <unitdate>1964, April 8</unitdate>
                       <unitid label="LCCNs">
                          <ref show="new" actuate="onrequest" href="https://lccn.loc.gov/95505406">95505406</ref>; <ref show="new" actuate="onrequest" href="https://lccn.loc.gov/95505454">95505454</ref>
                       </unitid>
                    </did>
                  </c03>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records[0]
            expect(archival_object.notes.length).to eq 1
            expect(archival_object.notes[0].type).to eq 'otherfindaid'
            expect(archival_object.notes[0].label).to eq 'Catalog Record'
            expect(archival_object.notes[0].subnotes[0]['content']).to eq "<extref actuate=\"onrequest\" href=\"https://lccn.loc.gov/95505406\" show=\"new\">95505406</extref>; <extref actuate=\"onrequest\" href=\"https://lccn.loc.gov/95505454\" show=\"new\">95505454</extref>"
            expect(archival_object.component_id).to be_nil
          end
        end

        it "if the unitid contains a number that is identical to the resource id_0 value, ignore it" do
          xml = <<~EAD
                 <c03 id="mferd92e5248" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Episode #29, <date>1964, April 8</date>
                       </unittitle>
                       <unitdate>1964, April 8</unitdate>
                       <unitid label="LCCNs">95505454</unitid>
                    </did>
                  </c03>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            record.id_0 = "95505454"
            batch << record
            converter.run
            archival_object = closed_records[0]
            expect(archival_object.component_id).to be_nil
          end
        end

        it "if the unitid contains a number that is NOT identical to the resource id_0 value, use it as a component id" do
          xml = <<~EAD
                 <c03 id="mferd92e5248" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Episode #29, <date>1964, April 8</date>
                       </unittitle>
                       <unitdate>1964, April 8</unitdate>
                       <unitid label="LCCNs">95505454</unitid>
                    </did>
                  </c03>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            record.id_0 = "12345"
            batch << record
            converter.run
            archival_object = closed_records[0]
            expect(archival_object.component_id).to eq "95505454"
          end
        end

        # AS-359
        it "imports additional unitids as additional identifiers" do
          xml = <<~EAD
                 <c03 id="mferd92e5248" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Episode #29, <date>1964, April 8</date>
                       </unittitle>
                       <unitdate>1964, April 8</unitdate>
                       <unitid label="LABEL">95505454</unitid>
                       <unitid label="LABEL">95505455</unitid>
                       <unitid label="LABEL">95505456</unitid>
                    </did>
                  </c03>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records[0]
            expect(archival_object.component_id).to eq "LABEL: 95505454"
            expect(archival_object.additional_identifiers[0]).to eq "LABEL: 95505455"
            expect(archival_object.additional_identifiers[1]).to eq "LABEL: 95505456"
          end
        end
      end

      context "unitid has an id attribute with a ref_id value" do
        it "maps the id attribute to a ref_id" do
          # ms015015
          xml = <<~EAD
                 <c04 id="mferd91e7861" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">"A Conversation with Nancy Pelosi," video
              files, John F. Kennedy Presidential Library and Museum,   <date>2008 Aug. 4 </date> (Container 237, 2008,
              Aug.-Sept., general) </unittitle>
                       <unitdate encodinganalog="245$f">2008 Aug. 4 </unitdate>
                       <unitid id="JFK" label="Digital ID">
                          <ref show="replace" actuate="onrequest" target="JFK2">mss85761_131_026</ref>
                       </unitid>
                    </did>
                 </c04>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records[1]
            expect(archival_object.ref_id).to eq "JFK"
          end

          # ms019044
          xml = <<~EAD
                 <c06 id="mferd139e1147" level="file">
                    <did>
                       <unitid id="c73-1808">73-1808</unitid>
                       <unittitle encodinganalog="245$a">Laing v. United States</unittitle>
                    </did>
                 </c06>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records[0]
            expect(archival_object.ref_id).to eq "c73-1808"
          end
        end

        it "only takes the first id as a ref_id in cases of multiple digital instance unitids" do
          # ms009006
          xml = <<~EAD
                <c04 id="mferd106e16634" level="file">
                   <did>
                      <unittitle encodinganalog="245$a">"The Bushes Did 9-11" and related
             material, images and video files, <date>2005</date> (Container II:18,
             "Abnormal missives")</unittitle>
                      <unitdate encodinganalog="245$f" unitdatetype="inclusive">2005</unitdate>
                      <unitid label="Digital ID" id="digi1">mss77198_130_001</unitid>
                      <unitid label="Digital ID" id="digi2">mss77198_130_002</unitid>
                      <unitid label="Digital ID" id="digi3">mss77198_130_003</unitid>
                   </did>
                </c04>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records[3]
            expect(archival_object.ref_id).to eq "digi1"
          end
        end
      end
    end

    # AS-360 & AS-396
    context "unitid label normalizes to 'filename'" do
      context "unitid has sibling dao tag" do
        it "puts the filename in a digital_object_note" do
          xml = <<~EAD
                <c04 id="mferd6e11876" level="item">
                    <did>
                      <unittitle id="ref_id11454" encodinganalog="245$a">Song list and
                      production notes for SR11, <date localtype="inclusive" normal="2013-01-02">January 2, 2013</date>
                      </unittitle>
                      <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="2013-01-02">January 2, 2013</unitdate>
                      <unitid label="Filename">rcr1960-08-27.txt</unitid>
                      <dao daotype="borndigital" actuate="onload" show="new" label="Filepath">
                          <descriptivenote>
                            <p>RCR_Archive_Audio_High_Resolution_Files/The_Redwood_Canyon_Ramblers/rcr1960-08-27/</p>
                          </descriptivenote>
                      </dao>
                    </did>
                  </c04>
                EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
            batch << resource
            converter.run
            jsons = JSON.load_file(batch.get_output_path)
            digital_object = jsons.select {|record| record['jsonmodel_type'] == "digital_object" }.first
            expect(digital_object).not_to be_nil

            all_note_contents = digital_object['notes'].map {|note| note['content'][0]}

            expect(all_note_contents).to include("RCR_Archive_Audio_High_Resolution_Files/The_Redwood_Canyon_Ramblers/rcr1960-08-27/")
            expect(all_note_contents).to include("rcr1960-08-27.txt")

            access_note_text = "Access to this digital content is available onsite only and requires advance request. Consult reference staff for more information."
            expect(all_note_contents).to include(access_note_text)
          end
        end
      end

      context "unitid has no sibling dao tag" do
        it "creates digital objects from unitids with label 'Filename'" do
          xml = <<~EAD
                 <c04 id="mferd6e11876" level="item">
                    <did>
                       <unittitle id="ref_id11454" encodinganalog="245$a">Song list and
                       production notes for SR11, <date localtype="inclusive" normal="2013-01-02">January 2, 2013</date>
                       </unittitle>
                       <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="2013-01-02">January 2, 2013</unitdate>
                       <unitid label="Filename">rcr1960-08-27.txt</unitid>
                     </did>
                   </c04>
                 EAD
          with_converter_instance(xml) do |converter, batch, closed_records|
            record = ASpaceImport::JSONModel(:resource).new
            batch << record
            converter.run
            archival_object = closed_records.select {|rec| rec.jsonmodel_type == "archival_object" }.first
            digital_objects = closed_records.select {|rec| rec.jsonmodel_type == "digital_object" }
            expect(archival_object.instances[0].digital_object['ref']).to eq digital_objects[0].uri
            expect(archival_object.component_id).to be_nil
            expect(digital_objects.size).to eq 1
            expect(digital_objects[0].notes[0].content[0]).to eq "rcr1960-08-27.txt"
            expect(digital_objects[0].file_versions[0]['file_uri']).to eq "rcr1960-08-27.txt"
            expect(digital_objects[0].title).to eq archival_object.title
          end
        end
      end
    end
  end

  # AS-165
  describe "<list type='unordered'> handling" do

    it "converts list tags within a multipart note to unordered list subnotes" do
      # example from af022010.xml
      xml = <<~EAD
        <arrangement encodinganalog="351$a" id="mferd6e376v">
           <head>Arrangement</head>
           <p> The Neil V. Rosenberg bluegrass music collection is organized in three series: </p>
           <list listtype="unordered" mark="circle">
              <item>
                 <ref show="replace" actuate="onrequest" target="ref_id10001">Series 1.
              Tennessee-Tombigbee Folklife Survey and related materials</ref>
              </item>
              <item>
                 <ref show="replace" actuate="onrequest" target="ref_id10022">Series 2.
              Correspondence and contacts</ref>
              </item>
              <item>
                 <ref show="replace" actuate="onrequest" target="ref_id10027">Series 3. Sound
              recordings</ref>
              </item>
           </list>
           <p>Filepaths and digital files can be found in afc2002009_dc001. Please see the AFC
      reference staff for access.</p>
        </arrangement>
        EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        expect(resource.notes.size).to eq 1
        expect(resource.notes[0].subnotes.size).to eq 3
        expect(resource.notes[0].subnotes[0]['content']).to eq "The Neil V. Rosenberg bluegrass music collection is organized in three series:"
        expect(resource.notes[0].subnotes[1]['items']).to eq [
                                                            "<ref actuate=\"onrequest\" show=\"replace\" target=\"ref_id10001\">Series 1. Tennessee-Tombigbee Folklife Survey and related materials</ref>",
                                                            "<ref actuate=\"onrequest\" show=\"replace\" target=\"ref_id10022\">Series 2. Correspondence and contacts</ref>",
                                                            "<ref actuate=\"onrequest\" show=\"replace\" target=\"ref_id10027\">Series 3. Sound recordings</ref>"
                                                          ]
        expect(resource.notes[0].subnotes[2]['content']).to eq "Filepaths and digital files can be found in afc2002009_dc001. Please see the AFC reference staff for access."
      end
    end
  end

  # AS-210
  describe "<dao> tag handling" do
    it "maps the @href attribute to the file_uri field of the digital object file version" do
      xml = <<~EAD
              <dao daotype="derived" actuate="onload" show="embed"
                  href="https://hdl.loc.gov/loc.mss/ms014016.mss48595.0101">
                <descriptivenote>
                  <p>Digital content available</p>
                </descriptivenote>
              </dao>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        archival_object = ASpaceImport::JSONModel(:archival_object).new
        batch << archival_object
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.file_versions.first[:file_uri]).to eq "https://hdl.loc.gov/loc.mss/ms014016.mss48595.0101"
      end
    end

    # AS-229
    it "uses the preceding sibling <unititle> as the digital_object title" do
      xml = <<~EAD
              <c03 id="mferd338e6409" level="file">
                 <did>
                    <container localtype="df"/>
                    <unittitle>Bernstein, Burton to Leonard Bernstein, <date>1938 August 30</date>
                    </unittitle>
                    <unitdate encodinganalog="245$f">1938 August 30</unitdate>
                    <dao daotype="derived" actuate="onload" show="embed"
                         href="https://www.loc.gov/item/musbernstein.100060000">
                       <descriptivenote>
                          <p>Digital content available</p>
                       </descriptivenote>
                    </dao>
                 </did>
              </c03>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        batch << ASpaceImport::JSONModel(:resource).new
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.title).to eq "Bernstein, Burton to Leonard Bernstein"
      end
    end

    it "maps @daotype to the custom ead_dao_type field" do
      xml = <<~EAD
                <dao daotype="derived" actuate="onload" show="new"  href="https://www.loc.gov/item/afc2001001.101797/">
                  <descriptivenote>
                    <p>Digital content available</p>
                  </descriptivenote>
                </dao>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        archival_object = ASpaceImport::JSONModel(:archival_object).new
        batch << archival_object
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.ead_dao_type).to eq "derived"
      end
    end

    # AS-267
    it "creates digital object identifier from href" do
      xml = <<~EAD
                <dao daotype="derived" actuate="onload" show="new"  href="https://www.loc.gov/item/afc2001001.101797/">
                  <descriptivenote>
                    <p>Digital content available</p>
                  </descriptivenote>
                </dao>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        archival_object = ASpaceImport::JSONModel(:archival_object).new
        batch << archival_object
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.digital_object_id).to eq "afc2001001.101797"
        # As-291
        expect(digital_object.publish).to be_truthy
      end
    end

    # AS-551
    it "stips the prefix from the identifier for the MI repo" do
      xml = <<~EAD
                <dao daotype="derived" actuate="onload" show="new"  href="https://hdl.loc.gov/loc.mbrsmi/cdmmi.s1229m03076">
                  <descriptivenote>
                    <p>Digital content available</p>
                  </descriptivenote>
                </dao>
              EAD
      FactoryBot.create(:repo, repo_code: "mi")
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        archival_object = ASpaceImport::JSONModel(:archival_object).new
        batch << archival_object
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.digital_object_id).to eq "s1229m03076"
      end
    end


    # AS-267 / Consolidate Multiple DAOs
    it "can recognize multiple DAOs are a single digital object that appears in multiple instances" do
      xml = <<~EAD
          <snip>
          <c04 id="mferd6e44718" level="file">
             <did>
                <container localtype="box-folder">17/169</container>
                <unittitle id="ref_id11529" encodinganalog="245$a">C log (color
                photo log)</unittitle>
                <origination label="Author">
                   <name>
                      <part>American Folklife Center</part>
                   </name>
                </origination>
                <dao daotype="derived" actuate="onload" show="new"
                     href="https://hdl.loc.gov/loc.afc/afc1991023.afc1991023_17_169"
                     label="Digital content available">
                   <descriptivenote>
                      <p>afc1991023_17_169</p>
                   </descriptivenote>
                </dao>
                <physdesc encodinganalog="300" label="Extent">14 manuscript pages
                (8.5 x 14 inch or smaller)</physdesc>
             </did>
          </c04>
          <c04 id="mferd6e45072" level="file">
             <did>
                <container localtype="box-folder">17/169A</container>
                <unittitle id="ref_id11541" encodinganalog="245$a">B log
                (black-and-white photo log)</unittitle>
                <origination label="Author">
                   <name>
                      <part>American Folklife Center</part>
                   </name>
                </origination>
                <dao daotype="derived" actuate="onload" show="new"
                     href="https://hdl.loc.gov/loc.afc/afc1991023.afc1991023_17_169"
                     label="Digital content available">
                   <descriptivenote>
                      <p>afc1991023_17_169</p>
                   </descriptivenote>
                </dao>
                <physdesc encodinganalog="300" label="Extent">14 manuscript pages
                (8.5 x 14 inch or smaller)</physdesc>
                <didnote encodinganalog="500" label="Note">Black-and-white log
                starts on page 12</didnote>
             </did>
          </c04>
          </snip>
          EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
        batch << resource
        converter.run
        jsons = JSON.load_file(batch.get_output_path)
        digital_objects = jsons.select {|record| record['jsonmodel_type'] == "digital_object" }
        expect(digital_objects.size).to eq 1
        expect(digital_objects[0]['title']).to eq "afc1991023_17_169"
        archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
        expect(archival_objects[0]["instances"][1]["digital_object"]["ref"]).to eq digital_objects[0]["uri"]
        expect(archival_objects[1]["instances"][1]["digital_object"]["ref"]).to eq digital_objects[0]["uri"]
      end
    end

    # example from pnp/2002/pp020002.xml
    it "uses the descriptivenote for a title when the finalized unittitle is empty" do
      xml = <<~EAD
           <did>
              <container localtype="reel">2*</container>
              <container localtype="box">2</container>
              <unittitle encodinganalog="245$a" id="reel2">
                 <date localtype="inclusive" normal="1939/1941">1939, 1941</date>
              </unittitle>
              <unitdate unitdatetype="inclusive" normal="1939/1941" encodinganalog="245$f">1939, 1941</unitdate>
              <dao daotype="derived" actuate="onload" show="embed"
                   href="https://hdl.loc.gov/loc.pnp/fsahsr.002">
                 <descriptivenote>
                    <p>*Digital content available (Reel 2)</p>
                 </descriptivenote>
              </dao>
           </did>
              EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        archival_object = ASpaceImport::JSONModel(:archival_object).new
        batch << archival_object
        converter.run
        digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
        expect(digital_object.title).to eq "*Digital content available (Reel 2)"
      end
    end
  end

  # AS-230
  it "creates a digital object if a <unitid> tag within <c*/did> has a label 'Digital ID'" do
    xml = <<~EAD
            <c05 level="file">
               <did>
                  <unittitle encodinganalog="245$a"> "FY 99 NASA Life Sciences Task Book
                     Form," <date>1999</date>
                  </unittitle>
                  <unitid label="Digital ID">mss85426_060_147</unitid>
                  <unitdate encodinganalog="245$f">1999 </unitdate>
               </did>
            </c05>
            EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
      archival_object = records_in_working_file.select {|r| r.jsonmodel_type == "archival_object" }.first
      expect(digital_object.uri).to match /\/repositories\/import\/digital_objects\/import_/
      expect(archival_object.instances[0].digital_object["ref"]).to eq digital_object.uri
      expect(digital_object.title).to eq "\"FY 99 NASA Life Sciences Task Book Form\""
      expect(digital_object.digital_object_id).to eq "mss85426_060_147"
      # AS-291 - always publish
      expect(digital_object.publish).to be_truthy
      # AS-313 - no component_id for these kinds of unitids.
      expect(archival_object.component_id).to be_nil
    end
  end

  it "ensures unique digital_object_id and creates an instance for each occurrence" do
    xml = <<~EAD
           <record>
            <c03 level="file">
               <did>
                  <unittitle encodinganalog="245$a"> Biosciences Information Service, <date>
                        1993-1995 </date>
                  </unittitle>
                  <unitdate encodinganalog="245$f"> 1993-1995 </unitdate>
                  <unitid label="Digital ID">mss85579_042_069</unitid>
               </did>
            </c03>
            <c03 level="file">
               <did>
                  <unittitle encodinganalog="245$a"> Carnegie Institute of Washington,
                     Washington, D.C., <date> 1990-1995 </date>
                  </unittitle>
                  <unitdate encodinganalog="245$f"> 1990-1995 </unitdate>
                  <unitid label="Digital ID">mss85579_042_069</unitid>
                  <unitid label="Digital ID">mss85579_042_076</unitid>
                  <unitid label="Digital ID">mss85579_042_118</unitid>
               </did>
            </c03>
            </record>
            EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      digital_objects = records_in_working_file.select { |record| record.jsonmodel_type == "digital_object" }
      expect(digital_objects.size).to eq 3
      appears_twice = digital_objects.select { |record| record.digital_object_id == "mss85579_042_069" }
      expect(appears_twice.size).to eq 1
      archival_objects = records_in_working_file.select { |record| record.jsonmodel_type == "archival_object" }
      expect(archival_objects[0].instances[0].digital_object["ref"]).to eq appears_twice[0].uri
      expect(archival_objects[1].instances.map { |instance| instance.digital_object["ref"] }).to include appears_twice[0].uri
    end
  end

  # AS-246
  it "assigns titles conditionally" do
    xml = <<~EAD
           <record>
            <c03 level="file">
               <did>
                  <unittitle encodinganalog="245$a"> Biosciences Information Service, <date>
                        1993-1995 </date>
                  </unittitle>
                  <unitdate encodinganalog="245$f"> 1993-1995 </unitdate>
                  <unitid label="Digital ID">mss85579_042_069</unitid>
               </did>
            </c03>
            <c03 level="file">
               <did>
                  <unittitle encodinganalog="245$a"> Carnegie Institute of Washington,
                     Washington, D.C., <date> 1990-1995 </date>
                  </unittitle>
                  <unitdate encodinganalog="245$f"> 1990-1995 </unitdate>
                  <unitid label="Digital ID">mss85579_042_069</unitid>
                  <unitid label="Digital ID">mss85579_042_076</unitid>
                  <unitid label="Digital ID">mss85579_042_118</unitid>
               </did>
            </c03>
            </record>
            EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      jsons = JSON.load_file(batch.get_output_path)
      digital_objects = jsons.select { |record| record["jsonmodel_type"] == "digital_object" }
      expect(digital_objects.size).to eq 3
      appears_once = digital_objects.reject { |record| record["digital_object_id"] == "mss85579_042_069" }
      appears_twice = digital_objects.select { |record| record["digital_object_id"] == "mss85579_042_069" }
      expect(appears_twice.size).to eq 1
      archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
      expect(archival_objects[0]["instances"][0]["digital_object"]["ref"]).to eq appears_twice[0]["uri"]
      expect(archival_objects[1]["instances"].map { |instance| instance["digital_object"]["ref"] }).to include appears_twice[0]["uri"]
      appears_once_titles = appears_once.map { |record| record["title"] }.uniq
      expect(appears_once_titles).to eq ["Carnegie Institute of Washington, Washington, D.C."]
      appears_twice_titles = appears_twice.map { |record| record["title"] }.uniq
      expect(appears_twice_titles).to eq ["mss85579_042_069"]
    end
  end

  describe "Linked Agent Imports" do
    # AS-104
    it "creates a linked agent with role 'source' for each origination tag and uses the label for the 'relator' field" do
      xml = <<~EAD
         <origination label="Creator">
           <persname encodinganalog="100" source="lcnaf">
             <part>Latty, A. Sankey (Alexander Sankey)</part>
           </persname>
         </origination>
      EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        expect(resource.linked_agents[0]["role"]).to eq "source"
        expect(resource.linked_agents[0]["relator"]).to eq "cre"
      end
    end

    # AS-382
    it "ensures origination tags are importing at the AO level" do
      xml = <<~EAD
        <c04 id="mferd6e42174" level="file">
           <did>
              <unitid label="Call number">AFC 1991/023: CET-015</unitid>
              <unittitle id="ref_id11447" encodinganalog="245$a">Interview with
              Helen Zimmer and George Zimmer, Egg Harbor City, New Jersey,
                  <date localtype="inclusive" normal="1983-10-12">October 12,
                  1983</date>
              </unittitle>
              <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="1983-10-12">October 12, 1983</unitdate>
              <origination label="Photographer">
                 <name>
                    <part>Elaine Thatcher</part>
                 </name>
              </origination>
              <unitid label="Field project identifier">PFP-83-CET-015</unitid>
           </did>
        </c04>
      EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
        batch << resource
        converter.run
        batch.flush
        archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
        agent_persons = records_in_working_file.select { |record| record["jsonmodel_type"] == "agent_person" }
        expect(archival_objects[0].linked_agents.size).to eq 1
        expect(archival_objects[0].linked_agents[0]['ref']).to eq agent_persons[0].uri
      end
    end
  end

  describe "<languagedeclaration> import" do
    it "maps language and script to the finding aid data section" do
      xml = <<~EAD
      <languagedeclaration>
         <language langcode="eng" encodinganalog="040$b">English</language>
         <script scriptcode="Latn">Latin</script>
      </languagedeclaration>
      EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        expect(resource.finding_aid_language).to eq "eng"
        expect(resource.finding_aid_script).to eq "Latn"
      end
    end
  end

  # AS-241
  describe "LCCN field import" do
    it "populates resource.lccn with the id in the hred attribute of the ref tag inside <controlnote>" do
      xml = <<~EAD
               <controlnote id="lccnNote">
                 <p> Catalog Record: <ref actuate="onrequest" show="new" href="https://lccn.loc.gov/2020570130">https://lccn.loc.gov/2020570130</ref>
                 </p>
               </controlnote>
               EAD
      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new
        batch << resource
        converter.run
        expect(resource.id_0).to eq "2020570130"
        expect(resource.lccn).to eq "2020570130"
      end
    end
  end

  describe "ref tag conversion to extref" do
    it "converts ref tags to extref when there is an href attribute" do

      xml = <<~EAD
        <notestmt>
           <controlnote id="contactNote">
              <p>Contact information: <ref actuate="onrequest" href="https://hdl.loc.gov/loc.music/perform.contact" show="new">https://hdl.loc.gov/loc.music/perform.contact</ref>
              </p>
           </controlnote>
        </notestmt>
      EAD

      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
        batch << resource
        converter.run
        batch.flush
        expect(resource.notes[0].subnotes[0].content).to eq 'Contact information: <extref actuate="onrequest" href="https://hdl.loc.gov/loc.music/perform.contact" show="new">https://hdl.loc.gov/loc.music/perform.contact</extref>'
      end
    end

    it "doesn't convert ref tags to extref when there is a target attribute" do
      xml = <<~EAD
        <notestmt>
           <controlnote id="contactNote">
              <p>Contact information: <ref actuate="onrequest" show="new" target="ref_id10001">Music</ref>
              </p>
           </controlnote>
        </notestmt>
      EAD

      with_converter_instance(xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
        batch << resource
        converter.run
        batch.flush
        expect(resource.notes[0].subnotes[0].content).to eq 'Contact information: <ref actuate="onrequest" show="new" target="ref_id10001">Music</ref>'
      end
    end
  end

  describe "<origination> label mapping (AS-373)" do

    context "when a label maps to a standard term with a MARC code" do
      it "maps a standard label like 'Creator:' to its MARC code" do
         xml = <<~EAD
          <origination label="Creator:">
            <persname>John Doe</persname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          expect(linked_agent['role']).to eq('source')
          expect(linked_agent['relator']).to eq('cre')
        end
      end

      it "maps a messy, non-standard label like 'Related Names:' to a standard MARC code" do
        xml = <<~EAD
          <origination label="Related Names:">
            <corpname>Some Corporation</corpname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          expect(linked_agent['role']).to eq('source')
          expect(linked_agent['relator']).to eq('asn') # asn = Associated name
        end
      end

      it "maps case-insensitively" do
        xml = <<~EAD
          <origination label="PHOTOGRAPHER">
            <persname>Ansel Adams</persname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          expect(linked_agent['relator']).to eq('pht')
        end
      end
    end

    context "when a label maps to a standard term without a MARC code" do
      it "uses the standardized term as the relator value" do
        xml = <<~EAD
          <origination label="announcer">
            <persname>Don Pardo</persname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          # There is no MARC code for 'Announcer', so it should use the term itself.
          expect(linked_agent['relator']).to eq('Announcer')
        end
      end
    end

    context "when a label is not in the mapping hash" do
      it "uses the original label as a fallback" do
        xml = <<~EAD
          <origination label="Principal Investigator">
            <persname>Dr. Evelyn Reed</persname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          # this label isn't in our map, so it should be passed through directly.
          expect(linked_agent['relator']).to eq('Principal Investigator')
        end
      end
    end

    context "when the origination tag has no label attribute" do
      it "results in a nil relator" do
        xml = <<~EAD
          <origination>
            <persname>An Agent</persname>
          </origination>
        EAD
        with_converter_instance(xml) do |converter, batch|
          resource = ASpaceImport::JSONModel(:resource).new
          batch << resource
          converter.run
          linked_agent = resource.linked_agents.first

          # Without a label, the custom handler shouldn't set a relator.
          expect(linked_agent['relator']).to be_nil
        end
      end
    end
  end

  describe "AS-334: <unitid> label standardization" do

   # "Digtial ID" should be treated just like "Digital ID".
    context "when a label is misspelled" do
      it "corrects the label and processes it according to the standardized value" do
        xml = <<~EAD
          <c01 level="file">
            <did>
              <unittitle>My Digital Item</unittitle>
              <unitid label="Digtial ID">mistyped-digital-id-123</unitid>
            </did>
          </c01>
        EAD

        with_converter_instance(xml) do |converter, batch, records|
          batch << ASpaceImport::JSONModel(:resource).new
          converter.run

          digital_object  = records.find {|r| r.jsonmodel_type == 'digital_object'}
          archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}

          # should create a digital object, just as if the label was correct.
          expect(digital_object).not_to be_nil
          expect(digital_object.digital_object_id).to eq("mistyped-digital-id-123")
          expect(digital_object.title).to eq("My Digital Item")

          # should link the AO to the new DO via an instance.
          instance = archival_object.instances.find {|i| i.instance_type == 'digital_object'}
          expect(instance['digital_object']['ref']).to eq(digital_object.uri)

          # should not create a component_id from this.
          expect(archival_object.component_id).to be_nil
        end
      end
    end

    # Test the default "passthrough" behavior for labels not in our map.
    context "when a label is not in the map" do
      it "passes the label through and creates a standard component identifier" do
        xml = <<~EAD
          <c01 level="file">
            <did>
              <unittitle>Some Item</unittitle>
              <unitid label="Unmapped Custom ID">abc-123</unitid>
            </did>
          </c01>
        EAD

        with_converter_instance(xml) do |converter, batch, records|
          batch << ASpaceImport::JSONModel(:resource).new
          converter.run

          archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}

          # should create a standard component_id with the label prefixed.
          expect(archival_object.component_id).to eq("Unmapped Custom ID: abc-123")
          expect(archival_object.notes).to be_empty
        end
      end
    end

    # Test the 'do not import' mapping.
    context "when a label maps to 'do not import'" do
      it "skips the unitid tag entirely" do
        xml = <<~EAD
          <c01 level="file">
            <did>
              <unittitle>An Item to Ignore</unittitle>
              <unitid label="B">should-be-ignored</unitid>
            </did>
          </c01>
        EAD

        with_converter_instance(xml) do |converter, batch, records|
          batch << ASpaceImport::JSONModel(:resource).new
          converter.run

          archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}

          # The archival object should have no identifiers, instances, or notes from this tag.
          expect(archival_object.component_id).to be_nil
          expect(archival_object.additional_identifiers).to be_empty
          expect(archival_object.instances).to be_empty
          expect(archival_object.notes).to be_empty
        end
      end
    end

    # Test mapping to an 'odd' note.
    context "when a label maps to 'odd'" do
      it "creates a multipart odd note from the unitid" do
        xml = <<~EAD
          <c01 level="file">
            <did>
              <unittitle>Item with an Odd ID</unittitle>
              <unitid label="AFS number(s)">XYZ-123</unitid>
            </did>
          </c01>
        EAD

        with_converter_instance(xml) do |converter, batch, records|
          batch << ASpaceImport::JSONModel(:resource).new
          converter.run

          archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}
          note = archival_object.notes.first

          expect(archival_object.notes.size).to eq(1)
          expect(note.type).to eq('odd')
          expect(note.label).to eq('AFS number(s)') # The note label should be the original, descriptive label.
          expect(note.subnotes[0].content).to eq('XYZ-123')
          expect(archival_object.component_id).to be_nil
        end
      end
    end

    # Test mapping to a 'didnote'.
    context "when a label maps to 'didnote'" do
      it "creates a singlepart didnote from the unitid" do
        xml = <<~EAD
          <c01 level="file">
            <did>
              <unittitle>Descriptive Item</unittitle>
              <unitid label="Pulled from Series 3, Subseries 1, Box 15">Folder 5</unitid>
            </did>
          </c01>
        EAD

        with_converter_instance(xml) do |converter, batch, records|
          batch << ASpaceImport::JSONModel(:resource).new
          converter.run

          archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}
          note = archival_object.notes.first

          expect(archival_object.notes.size).to eq(1)
          expect(note.type).to eq('didnote')
          expect(note.label).to eq('Pulled from Series 3, Subseries 1, Box 15')
          expect(note.content).to eq(['Folder 5'])
          expect(archival_object.component_id).to be_nil
        end
      end
    end
  end

  # AS-361
  describe "c tag id attribute mapping" do
    it "maps ids starting with 'magmar' to a special field" do
      xml = <<~EAD
          <c03 id="magmar126XD.mferd1e6806" level="file">
            <did>
              <unittitle>Descriptive Item</unittitle>
              <unitid label="Pulled from Series 3, Subseries 1, Box 15">Folder 5</unitid>
            </did>
          </c03>
        EAD

      with_converter_instance(xml) do |converter, batch, records|
        batch << ASpaceImport::JSONModel(:resource).new
        converter.run
        archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}
        expect(archival_object.loc_magmar_id).to eq("magmar126XD.mferd1e6806")
      end
    end

    it "maps other ids to the standard ref_id field" do
      xml = <<~EAD
        <c03 id="ABC" level="file">
          <did>
            <unittitle>Descriptive Item</unittitle>
            <unitid label="Pulled from Series 3, Subseries 1, Box 15">Folder 5</unitid>
          </did>
        </c03>
      EAD

      with_converter_instance(xml) do |converter, batch, records|
        batch << ASpaceImport::JSONModel(:resource).new
        converter.run
        archival_object = records.find {|r| r.jsonmodel_type == 'archival_object'}
        expect(archival_object.loc_magmar_id).to be_nil
        expect(archival_object.ref_id).to eq "ABC"
      end
    end
  end

  describe "AS-378: Date Type Import Logic" do

    def run_date_conversion(xml_did_content)
      # Wrap the <did> content in the necessary parent tags for a valid import
      full_xml = "<archdesc>#{xml_did_content}</archdesc>"
      all_records = nil
      resource = nil # Define resource outside the block
      # Capture the third argument provided by the helper: 'records_in_working_file'
      with_converter_instance(full_xml) do |converter, batch, records_in_working_file|
        resource = ASpaceImport::JSONModel(:resource).new # Assign to the outer variable
        batch << resource
        converter.run
        # Use the captured records array directly
        all_records = records_in_working_file.map(&:to_hash)
      end
      return resource, all_records
    end

    context "when <unitdate> is at the Resource level" do

      it "imports a <unitdate> with unitdatetype='bulk' as a Bulk date" do
        resource, _ = run_date_conversion("<did><unitdate unitdatetype='bulk' normal='1950/1960'>circa 1950-1960</unitdate></did>")

        expect(resource['dates'].length).to eq(1)
        expect(resource['dates'][0]['date_type']).to eq('bulk')
      end

      it "imports a <unitdate> with unitdatetype='inclusive' as an Inclusive date" do
        resource, _ = run_date_conversion("<did><unitdate unitdatetype='inclusive' normal='1970'>1970</unitdate></did>")

        expect(resource['dates'].length).to eq(1)
        expect(resource['dates'][0]['date_type']).to eq('inclusive')
      end

      it "defaults to an Inclusive date when the unitdatetype attribute is missing" do
        resource, _ = run_date_conversion("<did><unitdate normal='1980'>1980</unitdate></did>")

        expect(resource['dates'].length).to eq(1)
        expect(resource['dates'][0]['date_type']).to eq('inclusive')
      end

      it "is case-insensitive and correctly handles unitdatetype='Bulk' and 'Inclusive'" do
        resource, _ = run_date_conversion(
          "<did>
            <unitdate unitdatetype='Bulk' normal='1990/1995'>1990-1995</unitdate>
            <unitdate unitdatetype='Inclusive' normal='2000'>2000</unitdate>
          </did>"
        )

        expect(resource['dates'].length).to eq(2)
        expect(resource['dates'][0]['date_type']).to eq('bulk')
        expect(resource['dates'][1]['date_type']).to eq('inclusive')
      end
    end

    context "when <unitdate> is at the Archival Object level" do

      it "imports a <unitdate> with unitdatetype='bulk' as a Bulk date" do
        _, records = run_date_conversion("<dsc><c level='file'><did><unitdate unitdatetype='bulk' normal='1955/1965'>circa 1955-1965</unitdate></did></c></dsc>")
        archival_object = records.find { |r| r['jsonmodel_type'] == 'archival_object' }

        expect(archival_object['dates'].length).to eq(1)
        expect(archival_object['dates'][0]['date_type']).to eq('bulk')
      end

      it "imports a <unitdate> with unitdatetype='inclusive' as an Inclusive date" do
        _, records = run_date_conversion("<dsc><c level='file'><did><unitdate unitdatetype='inclusive' normal='1975'>1975</unitdate></did></c></dsc>")
        archival_object = records.find { |r| r['jsonmodel_type'] == 'archival_object' }

        expect(archival_object['dates'].length).to eq(1)
        expect(archival_object['dates'][0]['date_type']).to eq('inclusive')
      end

      it "defaults to an Inclusive date when the unitdatetype attribute is missing" do
        _, records = run_date_conversion("<dsc><c level='file'><did><unitdate normal='1985/1995'>1985-1995</unitdate></did></c></dsc>")
        archival_object = records.find { |r| r['jsonmodel_type'] == 'archival_object' }

        expect(archival_object['dates'].length).to eq(1)
        expect(archival_object['dates'][0]['date_type']).to eq('inclusive')
      end
    end
  end

  describe "extent portion setting" do

    let(:physdesc) {
      xml  = <<~PHYSDESC
        <physdesc label="Extent (whole collection)" encodinganalog="300">
          2 items
        </physdesc>
        <physdesc label="Extent" encodinganalog="300">
          3 (items)
        </physdesc>
        <physdesc label="Extent" encodinganalog="300">
          3 things
        </physdesc>
      PHYSDESC
      xml
    }

    def run_conversion(xml_physdesc_content)
      full_xml = "<___>#{xml_physdesc_content}</___>"
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      resource.extents = []
      with_converter_instance(full_xml) do |converter, batch, records_in_working_file|
        batch << resource
        converter.run
        batch.flush
      end
      return resource
    end


    it "assigns extent portion 'whole' by default" do
      resource = run_conversion(physdesc)
      expect(resource.extents.map {|e| e['portion'] }.uniq).to eq ["whole"]
    end

    context "p&p repo" do
      it "assigns all extents portion 'part' if there are multiple extents" do
        FactoryBot.create(:repo, repo_code: "p&p")
        resource = run_conversion(physdesc)
        expect(resource.extents.map {|e| e['portion'] }.uniq).to eq ["part"]
      end
    end

    context "RS and MI repos" do
      it "assigns extent portion 'part' iff extent value contains a '('" do
        FactoryBot.create(:repo, repo_code: "rs")
        resource = run_conversion(physdesc)
        expect(resource.extents[0].portion).to eq "part"
        expect(resource.extents[1].portion).to eq "part"
        expect(resource.extents[2].portion).to eq "whole"
        FactoryBot.create(:repo, repo_code: "mi")
        resource = run_conversion(physdesc)
        expect(resource.extents[0].portion).to eq "part"
        expect(resource.extents[1].portion).to eq "part"
        expect(resource.extents[2].portion).to eq "whole"
      end
    end

    context "AFC repo" do
      it "assigns extent portion 'whole' if label contains 'Whole' or value contains 'item
'" do
        FactoryBot.create(:repo, repo_code: "afc")
        resource = run_conversion(physdesc)
        expect(resource.extents[0].portion).to eq "whole"
        expect(resource.extents[1].portion).to eq "whole"
        expect(resource.extents[2].portion).to eq "part"
      end
    end
  end

  # AS-451
  it "assigns borndigital ead_dao_type when creating digital objects from 'Digital ID'" do
    xml = <<~EAD
            <c03 id="mferd155e3097" level="file">
               <did>
                  <container localtype="df"/>
                  <unittitle id="ead10049z2" encodinganalog="245$a">3 Fine Faces, <date localtype="inclusive" normal="2023">circa 2023</date>
                  </unittitle>
                  <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="2023">circa
         2023</unitdate>
                  <unitid label="Digital ID">McKimFund_014</unitid>
                  <physdesc encodinganalog="300">Printed score; parts</physdesc>
               </did>
            </c03>
            EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      digital_object = records_in_working_file.select {|r| r.jsonmodel_type == "digital_object" }.first
      expect(digital_object.ead_dao_type).to eq "borndigital"
    end
  end
end
