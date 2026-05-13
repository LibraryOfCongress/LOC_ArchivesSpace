require_relative 'loc_converter_spec_helper'

describe "container handler" do
  # TODO: verify with LOC that this is correct behavior
  # See ms008007.xml for example.
  it "ignores empty container tags" do
    xml = <<~EAD
        <did>
          <container localtype="df"/>
        </did>
        EAD

    with_converter_instance(xml) do |converter, batch|
      archival_object = ASpaceImport::JSONModel(:archival_object).new
      batch << archival_object
      converter.run
      expect(archival_object.instances).to be_empty
    end
  end

  it "creates an instance from a <container> tag" do
    xml = <<~EAD
        <did>
          <container localtype="box">123</container>
        </did>
        EAD

    with_converter_instance(xml) do |converter, batch|
      archival_object = ASpaceImport::JSONModel(:archival_object).new
      batch << archival_object
      converter.run
      expect(archival_object.instances.size).to eq 1
      # AS-245
      expect(archival_object.instances.first.instance_type).to be_nil
    end
  end

  # from core tests
  it "maps <container> correctly" do
    xml = <<~EAD
                <did>
                  <container id="cid1" localtype="Box" label="Text">1</container>
                  <container parent="cid1" localtype="Folder">1</container>
                </did>
             EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      archival_object = ASpaceImport::JSONModel(:archival_object).new
      batch << archival_object
      converter.run
      sub_container = archival_object.instances[0]["sub_container"]
      expect(sub_container['type_2']).to eq('Folder')
      expect(sub_container["top_container"]["ref"]).to eq(records_in_working_file[0].uri)
    end
  end

  # AS-231 & AS-395
  it "maps <container> with combined type and indicator" do
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
                 <unittitle>Test AO</unittitle>
                 <container localtype="box-folder">MSS-501/1</container>
                 </did>
              </c>
           </dsc>
           </archdesc>
        </ead>
     EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      converter.run
      archival_object = records_in_working_file.find {|r| r['jsonmodel_type'] == 'archival_object'}
      top_container = records_in_working_file.find {|r| r['jsonmodel_type'] == 'top_container'}
      sub_container = archival_object.instances[0]["sub_container"]

      expect(top_container.type).to eq "box"
      expect(top_container.indicator).to eq "MSS-501"
      expect(sub_container['type_2']).to eq('folder')
      expect(sub_container['indicator_2']).to eq('1')
      expect(sub_container["top_container"]["ref"]).to eq(top_container.uri)
    end
  end

  # AS-251
  it "understands implied box in sibling nodes" do
    xml = <<~EAD
          <root>
           <c02 id="mferd13e492" level="item">
              <did>
                 <container localtype="box">1</container>
                 <container localtype="folder">1</container>
                 <unittitle>Collection Finding Aid</unittitle>
              </did>
           </c02>
           <c02 id="mferd13e503" level="file">
              <did>
                 <container localtype="folder">2</container>
                 <unittitle>Diskette status reports</unittitle>
              </did>
              <scopecontent>
                 <p>A description of the project's electronic files, their
                            arrangement and location.</p>
              </scopecontent>
           </c02>
           <c02 id="mferd13e512" level="file">
              <did>
                 <container localtype="folder">3</container>
                 <unittitle>Log status reports.</unittitle>
              </did>
              <scopecontent>
                 <p>Tables that note the status of individual logs for formatted
                            materials (sound recordings, graphic materials, and manuscripts) by fieldworker
                            and location (diskette, database, and printout).</p>
              </scopecontent>
           </c02>
          </root>
           EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      expect(top_containers.size).to eq 1
      expect(top_containers[0].type).to eq "box"
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      # we don't want two instances for the first ao
      expect(archival_objects[0].instances.size).to be 1
      sub_containers = archival_objects.map {|rec| rec.instances[0]["sub_container"] }
      expect(sub_containers.size).to eq 3
      sub_containers.each do |sc|
        expect(sc["top_container"]["ref"]).to eq top_containers[0].uri
      end
    end
  end

  # AS-549
  it "see above....but not for P&P!" do
    xml = <<~EAD
          <root>
           <c02 id="mferd13e492" level="item">
              <did>
                 <container localtype="box">1</container>
                 <container localtype="folder">1</container>
                 <unittitle>Collection Finding Aid</unittitle>
              </did>
           </c02>
           <c02 id="mferd13e503" level="file">
              <did>
                 <container localtype="box">2</container>
                 <container localtype="folder">2</container>
                 <unittitle>Diskette status reports</unittitle>
              </did>
           </c02>
           <c02 id="mferd13e512" level="file">
              <did>
                 <container localtype="box">1</container>
                 <container localtype="folder">3</container>
                 <unittitle>Log status reports.</unittitle>
              </did>
           </c02>
          </root>
           EAD
    FactoryBot.create(:repo, repo_code: "p&p")
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      expect(top_containers.size).to eq 2
      expect(top_containers[0].type).to eq "box"
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(archival_objects[0].instances.size).to be 1
      sub_containers = archival_objects.map {|rec| rec.instances[0]["sub_container"] }
      expect(sub_containers.size).to eq 3
      expect(sub_containers[0]["top_container"]["ref"]).to eq top_containers[0].uri
      expect(sub_containers[0]["type_2"]).to eq "folder"
      expect(sub_containers[0]["indicator_2"]).to eq "1"
      expect(sub_containers[1]["top_container"]["ref"]).to eq top_containers[1].uri
      expect(sub_containers[1]["type_2"]).to eq "folder"
      expect(sub_containers[1]["indicator_2"]).to eq "2"
      expect(sub_containers[2]["top_container"]["ref"]).to eq top_containers[0].uri
      expect(sub_containers[2]["type_2"]).to eq "folder"
      expect(sub_containers[2]["indicator_2"]).to eq "3"
    end
  end

  # AS-549
  it "another P&P edge case" do
    xml = <<~EAD
          <root>
          <c01 id="123" level="series">
           <did>
              <unittitle>foobar</unittitle>
           </did>
           <c02 id="mferd13e492" level="subseries">
              <did>
                 <unittitle>Collection Finding Aid</unittitle>
              </did>
              <c03 id="mferd4e1879" level="file">
                 <did>
                    <container localtype="box">7</container>
                    <container localtype="folder">1</container>
                    <unittitle id="ref_id10078" encodinganalog="245$a">Harold and Katherine Walker
           Album</unittitle>
                    <unitid label="Call No.">LOT 15575, no. 1115 (H)</unitid>
                    <physdesc encodinganalog="300" label="Extent">1 album [ca. 35
           photographs]</physdesc>
                 </did>
              </c03>
           </c02>
         </c01>
         <c01 id="456" level="series">
           <did>
              <unittitle>foobar</unittitle>
           </did>
           <c02 id="mferd4e2086" level="subseries">
              <did>
                 <unittitle id="ref_id10091" encodinganalog="245$a">Robert H. McNeill Albums,
        Scrapbooks and Portfolios, <date localtype="inclusive" normal="1930/1970">ca.
           1930-1970</date>
                 </unittitle>
                 <unitdate unitdatetype="inclusive" encodinganalog="245$f" normal="1930/1970">ca.
        1930-1970</unitdate>
                 <unitid label="Call No.">LOT 15578 (F) (H)</unitid>
                 <physdesc encodinganalog="300" label="Extent">287 photographs, 15 items</physdesc>
              </did>
           </c02>
          </c01>
          </root>
           EAD
    FactoryBot.create(:repo, repo_code: "p&p")
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      expect(top_containers.size).to eq 1
      expect(top_containers[0].type).to eq "box"
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(archival_objects[-2].instances.size).to eq 0
    end
  end

  # AS-274
  it "can understand comma separated data in container tags" do
    xml = <<~EAD
       <c04 id="mferd92e5277" level="file">
          <did>
             <container localtype="box-folder">72/5, 719/2</container>
             <unittitle encodinganalog="245$a">Long hot supper</unittitle>
          </did>
       </c04>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 2
      expect(top_containers[0].type).to eq "Box"
      expect(top_containers[1].type).to eq "Box"
      expect(top_containers[0].indicator).to eq "719"
      expect(top_containers[1].indicator).to eq "72"
      expect(archival_objects[0].instances.size).to eq 2
      expect(archival_objects[0].instances[0].sub_container["top_container"]["ref"]).to eq top_containers[1].uri
      expect(archival_objects[0].instances[1].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      expect(archival_objects[0].instances[0].sub_container["type_2"]).to eq "folder"
      expect(archival_objects[0].instances[1].sub_container["type_2"]).to eq "folder"
      expect(archival_objects[0].instances[0].sub_container["indicator_2"]).to eq "5"
      expect(archival_objects[0].instances[1].sub_container["indicator_2"]).to eq "2"
    end

    # and with a folder range:
    xml = <<~EAD
       <c04 id="mferd92e5295" level="file">
          <did>
             <container localtype="box-folder">73/3-4, 719/5</container>
             <unittitle encodinganalog="245$a">Whistle while you work</unittitle>
          </did>
       </c04>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 2
      expect(top_containers[0].type).to eq "Box"
      expect(top_containers[1].type).to eq "Box"
      expect(top_containers[0].indicator).to eq "719"
      expect(top_containers[1].indicator).to eq "73"
      expect(archival_objects[0].instances.size).to eq 2
      expect(archival_objects[0].instances[0].sub_container["top_container"]["ref"]).to eq top_containers[1].uri
      expect(archival_objects[0].instances[1].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      expect(archival_objects[0].instances[0].sub_container["type_2"]).to eq "folder"
      expect(archival_objects[0].instances[1].sub_container["type_2"]).to eq "folder"
      expect(archival_objects[0].instances[0].sub_container["indicator_2"]).to eq "3-4"
      expect(archival_objects[0].instances[1].sub_container["indicator_2"]).to eq "5"
    end
  end

  # AS-321 & AS-383
  it "will not import container ranges at the series level when there are children with containers \
      but will import the range information as a physdesc note" do
    xml = <<~EAD
          <c01 id="mferd3e751" level="series">
             <did>
                <container localtype="box">1-124, 142-153</container>
                <unittitle id="ref_id10001" encodinganalog="245$a">Music, <date localtype="inclusive" normal="1934/1993">1934-1993</date>
                </unittitle>
             </did>
             <c02 id="mferd3e768" level="file">
                <did>
                   <container localtype="box/folder">97/11</container>
                   <unittitle id="ref_id10002" encodinganalog="245$a">Abigail,
                   </unittitle>
                </did>
             </c02>
          </c01>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 1
      expect(top_containers[0].type).to eq "box"
      expect(top_containers[0].indicator).to eq "97"
      expect(archival_objects[1].instances.size).to eq 0
      expect(archival_objects[1].notes[0].type).to eq "physdesc"
      expect(archival_objects[1].notes[0].content[0]).to eq "Box: 1-124\nBox: 142-153"
      expect(archival_objects[0].instances.size).to eq 1
      expect(archival_objects[0].instances[0].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      expect(archival_objects[0].instances[0].sub_container["type_2"]).to eq "folder"
      expect(archival_objects[0].instances[0].sub_container["indicator_2"]).to eq "11"
    end
  end

  # AS-321
  it "will import container ranges at non series levels when there are no children with containers" do
    xml = <<~EAD
          <c01 id="mferd3e751" level="item">
             <did>
                <container localtype="box">1-124, 142-153</container>
                <unittitle id="ref_id10001" encodinganalog="245$a">Music, <date localtype="inclusive" normal="1934/1993">1934-1993</date>
                </unittitle>
             </did>
          </c01>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 136
      expect(archival_objects[0].instances.size).to eq 136
      expect(archival_objects[0].instances.map {|i| i.sub_container["top_container"]["ref"] }.sort).to eq(top_containers.map {|tc| tc['uri'] }.sort)
    end

    # and with some variations
    xml = <<~EAD
          <c01 id="mferd3e751" level="item">
             <did>
                <container localtype="pail">OV 1-124, OV 142-153</container>
                <unittitle id="ref_id10001" encodinganalog="245$a">Music, <date localtype="inclusive" normal="1934/1993">1934-1993</date>
                </unittitle>
             </did>
          </c01>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 136
      expect(top_containers[0].indicator).to eq "OV 153"
      expect(top_containers[-1].indicator).to eq "OV 1"
      expect(archival_objects[0].instances.size).to eq 136
      expect(archival_objects[0].instances.map {|i| i.sub_container["top_container"]["ref"] }.sort).to eq(top_containers.map {|tc| tc['uri'] }.sort)
    end

    # and another variation
    xml = <<~EAD
          <c01 id="mferd3e751" level="item">
             <did>
                <container localtype="pail">MSS1659-MSS1663</container>
                <unittitle id="ref_id10001" encodinganalog="245$a">Music, <date localtype="inclusive" normal="1934/1993">1934-1993</date>
                </unittitle>
             </did>
          </c01>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 5
      expect(top_containers[0].indicator).to eq "MSS1663"
      expect(top_containers[-1].indicator).to eq "MSS1659"
      expect(archival_objects[0].instances.size).to eq 5
      expect(archival_objects[0].instances.map {|i| i.sub_container["top_container"]["ref"] }.sort).to eq(top_containers.map {|tc| tc['uri'] }.sort)
    end
  end

  it "will import container ranges at series levels when there are no children with containers" do
    xml = <<~EAD
          <c01 id="mferd3e751" level="series">
             <did>
                <container localtype="box">1-124, 142-153</container>
                <unittitle id="ref_id10001" encodinganalog="245$a">Music, <date localtype="inclusive" normal="1934/1993">1934-1993</date>
                </unittitle>
             </did>
          </c01>
       EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 136
    end
  end

  # AS-295 MSS physdesc containers
  it "can interpet physdesc tags as containers" do
    xml = <<~EAD
      <stuff>
         <c04 id="mferd62e45462" level="file">
            <did>
               <unittitle encodinganalog="245$a">October term 1972</unittitle>
            </did>
            <c05 id="mferd62e45452" level="file">
               <did>
                  <container localtype="box">729</container>
                  <unitid>71-32 </unitid>
                  <unittitle encodinganalog="245$a">Flood v. Kuhn </unittitle>
                  <physdesc encodinganalog="300">(2 folders)</physdesc>
               </did>
            </c05>
         </c04>
         <c04 id="mferd62e45462" level="file">
            <did>
               <unittitle encodinganalog="245$a">October term 1972</unittitle>
            </did>
            <c05 id="mferd62e45466" level="file">
               <did>
                  <unitid>70-18 </unitid>
                  <unittitle encodinganalog="245$a">Roe v. Wade</unittitle>
               </did>
               <c06 id="mferd62e45472" level="file">
                  <did>
                     <unittitle encodinganalog="245$a">1970</unittitle>
                  </did>
               </c06>
               <c06 id="mferd62e45476" level="file">
                  <did>
                     <unittitle encodinganalog="245$a">1971</unittitle>
                  </did>
                  <c07 id="mferd62e45480" level="file">
                     <did>
                        <unittitle encodinganalog="245$a">July</unittitle>
                     </did>
                  </c07>
                  <c07 id="mferd62e45484" level="file">
                     <did>
                        <unittitle encodinganalog="245$a">Aug.</unittitle>
                        <physdesc encodinganalog="300">(1 folder)</physdesc>
                        <container localtype="box">730</container>
                        <physdesc encodinganalog="300">(1 folder)</physdesc>
                     </did>
                  </c07>
               </c06>
            </c05>
         </c04>
      </stuff>
       EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 2
      expect(archival_objects[4].instances.size).to eq 1
    end

    FactoryBot.create(:repo, repo_code: "mss")
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 2
      expect(archival_objects[0].instances.size).to eq 1
      # I guess subcontainer type and indicator should be nil?
      expect(archival_objects[0].instances[0].sub_container["type_2"]).to be_nil
      expect(archival_objects[0].instances[0].sub_container["indicator_2"]).to be_nil
      expect(archival_objects[0].instances[0].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      expect(archival_objects[0].extents.size).to eq 1
      expect(archival_objects[0].extents[0].number).to eq "2"
      expect(archival_objects[0].extents[0].extent_type).to eq "folders"
      expect(archival_objects[4].instances.size).to eq 2
      expect(archival_objects[4].instances[0].sub_container["type_2"]).to be_nil
      expect(archival_objects[4].instances[0].sub_container["indicator_2"]).to be_nil
      expect(archival_objects[4].instances[0].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      expect(archival_objects[4].instances[1].sub_container["type_2"]).to be_nil
      expect(archival_objects[4].instances[1].sub_container["indicator_2"]).to be_nil
      expect(archival_objects[4].instances[1].sub_container["top_container"]["ref"]).to eq top_containers[1].uri
      expect(archival_objects[4].extents.size).to eq 1
      expect(archival_objects[4].extents[0].number).to eq "2"
      expect(archival_objects[4].extents[0].extent_type).to eq "folders"
    end
  end

  # AS-367
  it "propagates container information between parent and child objects" do
    xml = <<~EAD
      <snip>
        <c02 id="mferd76e1120" level="file">
           <did>
              <container localtype="box">32</container>
              <unittitle encodinganalog="245$a">Albion College, Albion, Mich.,<date encodinganalog="245$f" localtype="inclusive"> 1978-1980</date>
              </unittitle>
              <unitdate encodinganalog="245$f" unitdatetype="inclusive"> 1978-1980</unitdate>
           </did>
        </c02>
        <c02 id="mferd76e1131" level="file">
           <did>
              <unittitle encodinganalog="245$a">Aluminum Co. of America, management program,
        <date encodinganalog="245$f" localtype="inclusive">1978</date>
              </unittitle>
              <unitdate encodinganalog="245$f" unitdatetype="inclusive">1978</unitdate>
           </did>
        </c02>
        <c02 id="mferd76e1158" level="file">
           <did>
              <unittitle encodinganalog="245$a">American Enterprise Institute for Public Policy
     Research</unittitle>
           </did>
           <c03 id="mferd76e1162" level="file">
              <did>
                 <unittitle encodinganalog="245$a">Administrative records</unittitle>
              </did>
              <c04 id="mferd76e1166" level="file">
                 <did>
                    <unittitle encodinganalog="245$a">Advisory Board</unittitle>
                 </did>
                 <c05 id="mferd76e1170" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Brandt, Karl, <date encodinganalog="245$f" localtype="inclusive">1960-1968, 1975</date>
                       </unittitle>
                       <unitdate encodinganalog="245$f" unitdatetype="inclusive">1960-1968,
              1975</unitdate>
                    </did>
                 </c05>
               </c04>
             </c03>
          </c02>
        </snip>
     EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 1
      expect(archival_objects.size).to eq 6
      archival_objects.each do |ao|
        expect(ao.instances.size).to eq 1
        expect(ao.instances[0].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      end
    end
  end

  # AS-367 con't
  it "propagates containers with non-numerical indicators too" do
    xml = <<~EAD
      <snip>
           <c02 id="mferd139e16621" level="file">
              <did>
                 <container localtype="box">OV 4</container>
                 <unittitle encodinganalog="245$a">Madeline McDowell Breckenridge
        papers</unittitle>
              </did>
              <c03 id="mferd139e16627" level="file">
                 <did>
                    <unittitle encodinganalog="245$a">Subject file</unittitle>
                 </did>
                 <c04 id="mferd139e16631" level="file">
                    <did>
                       <unittitle encodinganalog="245$a">Women's suffrage </unittitle>
                    </did>
                 </c04>
              </c03>
           </c02>
        </snip>
     EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      batch << ASpaceImport::JSONModel(:resource).new
      converter.run
      top_containers = records_in_working_file.select {|rec| rec.jsonmodel_type == "top_container" }
      archival_objects = records_in_working_file.select {|rec| rec.jsonmodel_type == "archival_object" }
      expect(top_containers.size).to eq 1
      expect(archival_objects.size).to eq 3
      archival_objects.each do |ao|
        expect(ao.instances.size).to eq 1
        expect(ao.instances[0].sub_container["top_container"]["ref"]).to eq top_containers[0].uri
      end
    end
  end

  # AS-263
  it "creates containers from unitids sometimes" do
    # example from rb019002.xml
    xml = <<~EAD
     <c03 id="mferd2e23010" level="file">
       <did>
          <unitid label="Box">23a</unitid>
          <unittitle id="ead20001" encodinganalog="245$a">Houdini - Amazing
 Exploits</unittitle>
       </did>
       <c04 id="mferd2e23016" level="file">
          <did>
             <unitid label="Box-Folder">23a/1</unitid>
             <unittitle id="ead20002" encodinganalog="245$a">Houdini - Amazing
    Exploits</unittitle>
          </did>
          <c05 id="mferd2e23022" level="item">
             <did>
                <unitid label="Sleeve">23a/1/a</unitid>
                <unittitle id="ead20003" encodinganalog="245$a">"This
       Week--Accused!"</unittitle>
             </did>
          </c05>
        </c04>
      </c03>
      EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new
      batch << resource
      converter.run
      top_container = records_in_working_file[0]
      expect(top_container.indicator).to eq("23a")
      child = records_in_working_file[2].instances[0]
      expect(child.sub_container["top_container"]["ref"]).to eq top_container.uri
      expect(child.sub_container["type_2"]).to eq("folder")
      expect(child.sub_container["indicator_2"]).to eq("1")
      grandchild = records_in_working_file[1].instances[0]
      expect(grandchild.sub_container["top_container"]["ref"]).to eq top_container.uri
      expect(grandchild.sub_container["type_2"]).to eq("folder")
      expect(grandchild.sub_container["indicator_2"]).to eq("1")
      expect(grandchild.sub_container["type_3"]).to eq("sleeve")
      expect(grandchild.sub_container["indicator_3"]).to eq("a")
    end
  end

  it "can infer the top container from the parent archival object" do
    # example from rb019002.xml
    xml = <<~EAD
           <c02 id="mferd2e366" level="subseries">
            <did>
               <container localtype="box-folder">1/1</container>
               <unittitle encodinganalog="245$a">Magic Clippings; Part 1</unittitle>
            </did>
            <c03 id="mferd2e372" level="item">
               <did>
                  <container localtype="sleeve">1/1/a</container>
                  <unittitle encodinganalog="245$a">Ashworth, Norman. "Before Your
         Eyes."</unittitle>
               </did>
            </c03>
            <c03 id="mferd2e378" level="item">
               <did>
                  <container localtype="sleeve">1/1/a</container>
                  <unittitle encodinganalog="245$a">"Asahi Rope and Balls Trick as Performed by
         Asahi Troupe."</unittitle>
               </did>
            </c03>
           </c02>
            EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new
      batch << resource
      converter.run
      top_container = records_in_working_file[0]
      expect(top_container.indicator).to eq("1")
      child1 = records_in_working_file[1].instances[0]
      expect(child1.sub_container["top_container"]["ref"]).to eq top_container.uri
      expect(child1.sub_container["type_2"]).to eq("folder")
      expect(child1.sub_container["indicator_2"]).to eq("1")
      expect(child1.sub_container["type_3"]).to eq("sleeve")
      expect(child1.sub_container["indicator_3"]).to eq("a")
      child2 = records_in_working_file[2].instances[0]
      expect(child2.sub_container["top_container"]["ref"]).to eq top_container.uri
      expect(child2.sub_container["type_2"]).to eq("folder")
      expect(child2.sub_container["indicator_2"]).to eq("1")
      expect(child2.sub_container["type_3"]).to eq("sleeve")
      expect(child2.sub_container["indicator_3"]).to eq("a")
      parent = records_in_working_file[3].instances[0]
      expect(parent.sub_container["top_container"]["ref"]).to eq top_container.uri
      expect(parent.sub_container["type_2"]).to eq("folder")
      expect(parent.sub_container["indicator_2"]).to eq("1")
    end
  end
end
