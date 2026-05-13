require_relative 'loc_converter_spec_helper'

describe "note importing" do
  # AS-254
  it "imports head tag into note label" do
    xml = <<~EAD
           <odd>
             <head id="artists">Primary Recording Artists</head>
             <p>
             The following is a list extracted from the "Recording Artists" field of the NCTA database. See
             <ref target="accessandrestrictions">Access and Restrictions</ref>
             section for more information about the NCTA database. The list is provided to show the range of musicians and bands represented in the collection. See Appendix:
             <ref href="https://hdl.loc.gov/loc.afc/afcead.af020002.apx" actuate="onrequest" show="new">Recording Artists</ref>
             for additional performers accompanying the musicians and bands in this list, as well as instrumentation.
             </p>
           </odd>
           EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0].label).to eq "Primary Recording Artists"
      expect(resource.notes[0].subnotes[0]["content"]).to eq 'The following is a list extracted from the "Recording Artists" field of the NCTA database. See <ref target="accessandrestrictions">Access and Restrictions</ref> section for more information about the NCTA database. The list is provided to show the range of musicians and bands represented in the collection. See Appendix: <extref actuate="onrequest" href="https://hdl.loc.gov/loc.afc/afcead.af020002.apx" show="new">Recording Artists</extref> for additional performers accompanying the musicians and bands in this list, as well as instrumentation.'
    end
  end

  # AS-303
  it "can import tables etc" do
    xml = <<~EAD
                <odd id="mferd138e3154v">
                   <head althead="Locations" id="appendix">Appendix: Locations by Date</head>
                   <p>This appendix serves as an aid to researchers to better identify Schuyler’s locations by
          city and country and to find resources within the collection. The information in this
          appendix was compiled from Schuyler’s correspondence and scrapbook. </p>
                   <table>
                      <tgroup cols="10" align="left">
                         <colspec colnum="1" colname="col1" colwidth="30*"/>
                         <colspec colnum="2" colname="col2" colwidth="80*"/>
                         <thead valign="bottom">
                            <row>
                               <entry colname="col1" morerows="0">Date</entry>
                               <entry colname="col2" morerows="0">Location</entry>
                            </row>
                         </thead>
                         <tbody valign="top">
                            <row>
                               <entry colname="col1" morerows="0">1859, Nov. 12</entry>
                               <entry colname="col2" morerows="0">New Haven, Connecticut</entry>
                            </row>
                            <row>
                               <entry colname="col1" morerows="0">1862, Jan. 21</entry>
                               <entry colname="col2" morerows="0">New Haven, Connecticut</entry>
                            </row>
                         </tbody>
                      </tgroup>
                   </table>
                </odd>
                EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0].label).to eq "Appendix: Locations by Date"
      expect(resource.notes[0].subnotes[0]["content"]).to eq "This appendix serves as an aid to researchers to better identify Schuyler’s locations by city and country and to find resources within the collection. The information in this appendix was compiled from Schuyler’s correspondence and scrapbook.\n\n<table> <tgroup align=\"left\" cols=\"10\"> <colspec colname=\"col1\" colnum=\"1\" colwidth=\"30*\"/> <colspec colname=\"col2\" colnum=\"2\" colwidth=\"80*\"/> <thead valign=\"bottom\"> <row> <entry colname=\"col1\" morerows=\"0\">Date</entry> <entry colname=\"col2\" morerows=\"0\">Location</entry> </row> </thead> <tbody valign=\"top\"> <row> <entry colname=\"col1\" morerows=\"0\">1859, Nov. 12</entry> <entry colname=\"col2\" morerows=\"0\">New Haven, Connecticut</entry> </row> <row> <entry colname=\"col1\" morerows=\"0\">1862, Jan. 21</entry> <entry colname=\"col2\" morerows=\"0\">New Haven, Connecticut</entry> </row> </tbody> </tgroup> </table>"
    end
  end

  it "can import bibref tags as bibliography note items" do
    xml = <<~EAD
        <bibliography encodinganalog="510" id="mferd407e713v">
           <head>Bibliography</head>
           <bibref>
              <title>
                 <part>Guide to the Special Collections of Prints and Photographs in the Library
              of Congress</part>
              </title> / compiled by Paul Vanderbilt. Washington, D.C. : 1955, no. 534 (Available
      in the <ref show="new" actuate="onrequest" href="https://lccn.loc.gov/54060020">Prints and Photographs Reading Room</ref> and online through <ref show="new" actuate="onrequest"
                   href="https://catalog.hathitrust.org/Record/001469580">HathiTrust</ref>)
            </bibref>
           <bibref>
              Another bibref
            </bibref>
         </bibliography>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0].items.size).to eq 2
    end
  end

  it "can import archref tags" do
    xml = <<~EAD
        <relatedmaterial id="mferd1759e247">
           <head>Related Materials</head>
           <archref>A Stitch in Time: African American Quilters of
        Oakland, AFC 1991/010</archref>
           <archref>Alliance for American Quilts Interview
        Collection, AFC 2007/009</archref>
           <archref>Blue Ridge Parkway Folklife Project
        Collection, AFC 1982/009</archref>
           <archref>Lisa Oshins Quilt Survey Collection, AFC
        1988/033</archref>
           <archref>Quilts and Quiltmaking in America, 1978-1996
        Online Presentation Collection, AFC 1999/024</archref>
           <archref>The Quilters' Save Our Stories Project,
        Lecture by Bernard L. Herman, AFC 2007/034</archref>
        </relatedmaterial>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0].subnotes.size).to eq 1
      expect(resource.notes[0].subnotes[0].items.size).to eq 6
      expect(resource.notes[0].subnotes[0].items[0]).to eq "A Stitch in Time: African American Quilters of Oakland, AFC 1991/010"
    end
  end
end

describe "didnote handling" do
  # AS-86
  it "can import a didnote tag as a note" do
    xml = <<~EAD
        <c04 id="mferd6e45072" level="file">
           <did>
              <unittitle id="ref_id11541" encodinganalog="245$a">B log
              (black-and-white photo log)</unittitle>
              <didnote encodinganalog="500" label="Note">Black-and-white log
              starts on page 12</didnote>
           </did>
        </c04>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
      expect(archival_objects[0].notes[0]['type']).to eq("didnote")
      expect(archival_objects[0].notes[0]['content']).to eq(["Black-and-white log starts on page 12"])
      expect(archival_objects[0].notes[0]['label']).to eq("Note")
    end
  end

  # AS-347 more didnote handling
  it "can import a didnote for a resource and can ignore insignificant markup at the beginning" do
    xml = <<~EAD
         <did>
            <unittitle id="ref_id11541" encodinganalog="245$a">B log
            (black-and-white photo log)</unittitle>
            <didnote encodinganalog="500" label="Note"><emph render="italic">Note:</emph>Black-and-white log
            starts on page 12</didnote>
            <didnote encodinganalog="500" label="Note"><emph render="italic">Note: </emph>Black-and-white log
            starts on page 12</didnote>
         </did>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0]['type']).to eq("didnote")
      expect(resource.notes[0]['content']).to eq(["Black-and-white log starts on page 12"])
      expect(resource.notes[0]['label']).to eq("Note")
     expect(resource.notes[1]['type']).to eq("didnote")
      expect(resource.notes[1]['content']).to eq(["Black-and-white log starts on page 12"])
      expect(resource.notes[1]['label']).to eq("Note")
    end
  end

  it "will use a head tag content as a didnote label" do
    xml = <<~EAD
        <c04 id="mferd6e45072" level="file">
           <did>
              <unittitle id="ref_id11541" encodinganalog="245$a">B log
              (black-and-white photo log)</unittitle>
              <didnote encodinganalog="500" label="Note"><head>LABEL</head> Black-and-white log
              starts on page 12</didnote>
           </did>
        </c04>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
      expect(archival_objects[0].notes[0]['type']).to eq("didnote")
      expect(archival_objects[0].notes[0]['content']).to eq(["Black-and-white log starts on page 12"])
      expect(archival_objects[0].notes[0]['label']).to eq("Note")
    end
  end

  it "correctly imports didnote labels based on the specified priority (AS-374)" do
    xml = <<~EAD
      <c01 level="series">
        <did>
          <unittitle>Test Series</unittitle>
          <didnote encodinganalog="500" label="Architect:">Skidmore, Owings, &amp; Merrill (SOM)</didnote>
          <didnote encodinganalog="500"><head>Location</head>Columbus, IN</didnote>
          <didnote encodinganalog="500">This is a standard note.</didnote>
          <didnote encodinganalog="500" label="Attribute Should Win"><head>Head Should Lose</head>This is the content.</didnote>
        </did>
      </c01>
    EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      archival_objects = records_in_working_file.select { |record| record["jsonmodel_type"] == "archival_object" }
      notes = archival_objects[0].notes

      expect(notes.count).to eq(4)

      # label attribute
      expect(notes[0]['type']).to eq("didnote")
      expect(notes[0]['label']).to eq("Architect:")
      expect(notes[0]['content']).to eq(["Skidmore, Owings, & Merrill (SOM)"])

      # <head> tag
      expect(notes[1]['type']).to eq("didnote")
      expect(notes[1]['label']).to eq("Location")
      expect(notes[1]['content']).to eq(["Columbus, IN"])

      # Default "Note"
      expect(notes[2]['type']).to eq("didnote")
      expect(notes[2]['label']).to eq("Note")
      expect(notes[2]['content']).to eq(["This is a standard note."])

      note_with_both = notes[3]
       expect(note_with_both['type']).to eq("didnote")
       expect(note_with_both['label']).to eq("Attribute Should Win")
       expect(note_with_both['content']).to eq(["This is the content."])
    end
  end
end

describe "additional note examples" do

  # example from music/2006/mu006002.xml
  it "can ingest a huge nested list" do
    xml = <<~EAD
     <odd localtype="index" id="mferd76e16238v">
        <head id="index_01" althead="Audiovisual">Audiovisual Materials</head>
        <list listtype="unordered" mark="circle">
           <item>
              <emph render="underline">
                 <emph render="bold">Record Albums, Audio Tapes, Audio Discs, Audio Cassettes, and
        Compact Discs</emph>
              </emph>
              <list listtype="unordered" mark="circle">
                 <item>[Note: These materials are located in the Motion Picture, Broadcasting, and
        Recorded Sound Division (MBRS) of the Library of Congress. As available, LC
        record numbers are indicated next to each record album, audio tape, audio disc,
        audio cassette or compact disc. Audio discs are demo/rehearsal/personal disc
        recordings not released commercially. These are not cross-referenced with
        individual productions.]</item>
                 <item>
                    <emph render="italic">All That Jazz</emph> Files<list listtype="unordered" mark="circle">
                       <item>1) Booth Colman, actor, :30 spot for casting [audio recording
              tape]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">All That Jazz</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Casablanca original motion picture soundtrack] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Annie</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia, original motion picture soundtrack, Albert Finney/Carol
              Burnett/Ann Reinking], 1982] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Atlantic City</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[note script listed elsewhere] [cassette tape]</item>
                       <item>"Ballad # 3, Ballad # 4, Arnold Schwarzwald" [audio recording
              disc]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Bells Are Ringing</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia original cast recording, Judy Holliday] [record
              album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Bells Are Ringing</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia digitally remastered from the original master tapes, Judy
              Holliday, 1956] [CD]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Big Deal</emph>
                    <list listtype="unordered" mark="circle">
                       <item>Tony Awards, "Beat Me Daddy" [cassette tape]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Cabaret</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[ABC original sound track recording, Liza Minnelli/Michael York/Joel
              Grey, 1972] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Cabaret</emph>
                    <list listtype="unordered" mark="circle">
                       <item>These were with misc. Cabaret files<list listtype="unordered" mark="circle">
                             <item>1) "Introspection," Mike Alterman [audio recording tape]</item>
                             <item>2) "Earth," Acts I &amp; II [audio recording tape]</item>
                             <item>3) "Ben Vereen: 'Play Piper Play, etc.'" [audio recording
                    tape]</item>
                          </list>
                       </item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Can-Can</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Capitol, original Broadway cast recording, Lilo/Peter Cookson/Gwen
              Verdon] [record album]</item>
                    </list>
                 </item>
                 <item>Carmen Cavallaro, The Poet of the Piano, Medleys from <emph render="italic">Sweet Charity</emph>, Finian's Rainbow,<list listtype="unordered" mark="circle">
                       <item>
                          <emph render="italic">Funny Girl</emph>, Star [Decca] [record
              album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Chicago</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Arista original cast album, Gwen Verdon/Chita Rivera/Jerry Orbach,
              1975] [record album - 3 copies]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Chicago</emph> And <emph render="italic">All That
           Jazz</emph>, Lee Konitz Big Band Jazz of the<list listtype="unordered" mark="circle">
                       <item>Broadway Hit Musical [Groove Merchant, 1975] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Chicago</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[only handwritten ID, not commercial tape] [cassette tape]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Chicago</emph>, "Montage, :60" produced by Elaine
        Thompson [audio recording tape]</item>
                 <item>
                    <emph render="italic">Chicago</emph>, "I Love You" [audio recording
        tape]</item>
                 <item>
                    <emph render="italic">Chicago</emph>, Act I &amp; Act II [2 separate tapes],
        Aarhus Theatre,<list listtype="unordered" mark="circle">
                       <item>Denmark production, 9-10/76 [cassette tapes]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Damn Yankees</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original soundtrack recording, Gwen Verdon/Tab Hunter/Ray
              Walston, 1958] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Damn Yankees</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast recording, Gwen Verdon/Stephen Douglass/Ray
              Walston] [Gwen Verdon: Baseball uniform cover] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Damn Yankees</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast recording, Gwen Verdon/Stephen Douglass/Ray
              Walston, 1955] [record album, CD]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Damn Yankees</emph>, rehearsal tape?, songs listed on
        box, undated [audio recording tape]</item>
                 <item>
                    <emph render="italic">Damn Yankees</emph> [marked # R9250-1] [audio recording
        disc]</item>
                 <item>
                    <emph render="italic">Danny Kaye Show</emph>, Gwen Verdon, "Downtown" [audio
        recording tape]</item>
                 <item>
                    <emph render="italic">Eating Raoul</emph> [note script listed elsewhere] [audio
        cassette tape]</item>
                 <item>
                    <emph render="italic">Ed Sullivan Show</emph>, Gwen Verdon, 2/1/790 [audio
        recording tape]</item>
                 <item>
                    <emph render="italic">A Funny Thing Happened On The Way To The Forum</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Capitol original Broadway cast recording, Jack Cole, choreography]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">The Girl I Left Home For</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA, Gwen Verdon, 1956] [record album]</item>
                    </list>
                 </item>
                 <item>The Girls Against The Boys<list listtype="unordered" mark="circle">
                       <item>[Capitol] [45 rpm. record]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Give A Girl A Break</emph>, "In Our United States," Bob
        Fosse [labeled "Nola studios" [audio recording disc]</item>
                 <item>
                    <emph render="italic">Give A Girl A Break</emph>, "In Our United States," Bob
        Fosse [MGM, marked "Rehearsal" 8/15/53?"] [audio recording disc]</item>
                 <item>"Gwen Verdon" [Anne Auchland (?) interview] [audio cassette tape]</item>
                 <item>"Gwen Verdon" [labeled (topmost# in series) # F2PB - 8026] [2 audio
        recording discs]</item>
                 <item>Gwen Verdon Prepares To Move<list listtype="unordered" mark="circle">
                       <item>[Kimbo Educational, 1973] [2 brochures, record album missing]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Happy Birthday, Mr. Abbott!</emph> Act I, Act 2 [2
        cassette tapes]</item>
                 <item>
                    <emph render="italic">How To Succeed In Business Without Really Trying</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original Broadway cast recording, Robert Morse/Rudy Vallee]
              [record album - 2 copies]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">How To Succeed In Business Without Really Trying</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[UA original motion picture recording, Robert Morse/Rudy Vallee]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">How To Succeed In Business Without Really Trying</emph>
                    <list listtype="unordered" mark="circle">
                       <item>(Ray Ellis and His Orchestra Play Frank Loesser's Music) [RCA, 1961]
              [record album]</item>
                    </list>
                 </item>
                 <item>"I Wanna Be A Dancin' Man" Verdon - Fosse [audio disc recording]</item>
                 <item>
                    <emph render="italic">Jamaica</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast album, Jack Cole, choreographer, 1957] [record
              album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Jonathan Winters Show</emph>, "Sweet Talk," Gwen Verdon,
        air 9/25/68 [audio recording tape]</item>
                 <item>
                    <emph render="italic">Kismet</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia original Broadway cast, Jack Cole, choreography, 1953]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Kiss Me Kate</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[MGM recording from film soundtrack, Kathryn Grayson/Howard Keel]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Little Me</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original Broadway cast recording, Sid Caesar/Virginia, 1962]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Little Me</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA, original Broadway cast recording, Sid Caesar/Virginia Martin]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Liza With A Z [Columbia, 1972] [record album]</emph>
                 </item>
                 <item>
                    <emph render="italic">Liza With A Z</emph> [Columbia, 1972] [8 track cassette
        tape]</item>
                 <item>Lyle, Lyle Crocodile, Read by Gwen Verdon [Caedmon, 1969] [record
        album]</item>
                 <item>
                    <emph render="italic">Me and Juliet</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast recording, Isabel Bigley/Joan McCracken] [record
              album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">The Merry Widow</emph>, Songs by Fernando Lamas [MGM,
        recorded from the motion picture soundtrack] [record album]</item>
                 <item>
                    <emph render="italic">New Girl In Town</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast recording, Gwen Verdon/Thelma Ritter/George
              Wallace, 1957] [record album - 2 copies]</item>
                    </list>
                 </item>
                 <item>"On the Other Side of the Tracks, Tony Bennett" [audio recording
        disc]</item>
                 <item>
                    <emph render="italic">The Pajama Game</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia digitally remastered, John Raitt/Janis Paige/Eddie Foy, Jr.]
              [CD]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">The Pajama Game</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia original cast album, John Raitt/Janis aige/Eddie Foy, Jr.]
              [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Pal Joey</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Columbia digitally remastered from original master, Vivienne
              Segal/Harold Lang, 1950] [CD]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Pal Joey</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[That's Entertainment Records, original 1980 London cast, Sian
              Phillips/Denis Lawson] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Pippin</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Motown original Broadway cast album, John Rubinstein/Ben Vereen,
              1972] [CD]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Pippin</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Motown original cast album, 1972] [record album]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Pleasures and Palaces</emph>, Demos [audio disc
        recording]</item>
                 <item>
                    <emph render="italic">Redhead</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[RCA original cast recording, Gwen Verdon/Richard Kiley, 1959] [record
              album - 2 copies]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Redhead</emph>, The Rex Stewart Quintet [Design] [record
        album]</item>
                 <item>
                    <emph render="italic">Redhead</emph>, Selections from, Hill Bowen and His
        Orchestra [RCA Camden, 1959] [record album]</item>
                 <item>[<emph render="italic">Redhead</emph>] La Peli Roja [Mexican] [RCA, Armando
        Calvo/Virma Gonzalez] [record album]</item>
                 <item>[<emph render="italic">Redhead</emph>] Meyer Davis Plays <emph render="italic">Redhead</emph> for Dancing [RCA, 1959] [record album - 2
        copies, one autographed by Meyer Davis]</item>
                 <item>
                    <emph render="italic">Redhead</emph> [listing from box]:<list listtype="unordered" mark="circle">
                       <item>1. "It Doesn't Take a Minute"</item>
                       <item>2. "Love and ? Don't Mix"</item>
                       <item>3. "Two Faces in the Dark"</item>
                       <item>4. "You Love I"</item>
                       <item>5. "Simpson Sisters"</item>
                       <item>6. "What Has She Got"</item>
                       <item>7. "Dream in a Fog"</item>
                       <item>8. "Just For Once"</item>
                       <item>9. "Tom &amp; Wedding Band"</item>
                       <item>10. "You're My Cup of Tea" [audio recording tape]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="italic">Redhead</emph>, "We Love's Ye, Jimey," Gwen Verdon [audio
        recording disc]</item>
                 <item>
                    <emph render="italic">Redhead</emph> (?), "Just For Once," Gwen Verdon [audio
        recording disc]</item>
                 <item>
                    <emph render="italic">Redhead</emph>, "The Right Finger of Me Left Hand," Gwen
        Verdon [audio recording disc - 2 copies]</item>
                 <item>
                    <emph render="italic">Redhead</emph> (?), "It Doesn't Take a Minute," Gwen
        Verdon [audio recording disc]</item>
                 <item>
                    <emph render="italic">Redhead</emph>, 5/2/58, 6 songs [listed on box],
        "Property of Dorothy Fields," [audio recording tape]</item>
                 <item>Relaxation - The Key To Life [Kimbo, 1972] [record album, brochure]</item>
                 <item>Shades Of Today, Pat Williams [including "Bubbles Was A Cheerleader" [MGM]
        [record album]</item>
                 <item>"The Song of Christmas," Gwen Verdon [audio recording disc]</item>
                 <item>The Story Of Ferdinand, Gwen Verdon Reading [Caedmon, 1971] [record
        album]</item>
                 <item>"Sunny &amp; Very Good Year, Bill Bogart &amp; Ron Parker" [audio recording
        disc]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph> [Columbia original Broadway cast
        recording, Gwen Verdon] [record album - 2 copies, CD]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph> [Decca original soundtrack album of
        the motion picture, Shirley MacLaine/Sammy Davis, Jr.] [record album - 2
        copies]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, Debbie Allen as Charity [EMI
        Broadway cast album, 1986] [record album, cassette tape]</item>
                 <item>Music From <emph render="italic">Sweet Charity</emph>, Sammy Kaye and His
        Orchestra [Decca] [record album]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, Opening Night [This seems to be a
        dupe of "Opening Night at the Palace, the New Musical Comedy Hit, A Special
        On-the-scene Report from The Palace Opening and Cast Party at the Waldorf" by
        Radio Personality Fred Robbins]; Side B has "The Girl I Left Home For", Gwen
        Verdon [audio cassette tape]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, rehearsal ?, [listing from
           box];<list listtype="unordered" mark="circle">
                       <item>1. "Charity's Theme"</item>
                       <item>2. "You Should See Yourself"</item>
                       <item>3. "Soliloquy -Raincheck" [audio recording tape]</item>
                    </list>
                 </item>
                 <item>"Sweet Charity" [labeled # 02013] [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "Big Spender" [labeled # 02013,
        1/31/68] [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "Rich Man's Frug" [labeled # 02013]
        [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "Rich Man's Frug" Part II, Part III
        [labeled # 02013] [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph> [labeled only # 02013] [audio disc
        recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "Big Spender" [labeled # 02013,
        2/2/68] [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph> [labeled "Notable Music, Lida
        Music"] [audio disc recording - 2 copies]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "It's A Nice Face" [labeled #02013,
        4/30/68] [audio disc recording]</item>
                 <item>
                    <emph render="italic">Sweet Charity</emph>, "Where Am I Going &amp; Tag"
        [labeled #02013, 4/24/68] [audio disc recording]</item>
                 <item>"Tears of Joy" Frank Loesser [audio disc recording]</item>
              </list>
           </item>
           <item>
              <emph render="underline">
                 <emph render="bold">Audio Cassette Tapes</emph>
              </emph>
              <list listtype="unordered" mark="circle">
                 <item>"Submissions and Miscellaneous" [Note: These are not cross referenced with
        individual shows.]<list listtype="unordered" mark="circle">
                       <item>1. It's Raining Men [Paul Jarbara Demo]</item>
                       <item>2. Love Me Again [Rita Coolidge]</item>
                       <item>3. Pink Floyd/Led Zepplin</item>
                       <item>4. Liza/Mein Herr</item>
                       <item>5. Not Labeled</item>
                       <item>6. Piano ?? demo??</item>
                       <item>7. Jed Feuer</item>
                       <item>8. Tony Webster Songs</item>
                       <item>9. Dedication To "Love Is" [cassette 31]</item>
                       <item>10. The Musical: The Model</item>
                       <item>11. Herb Alpert: "Wild Romance;" The Pointer Sisters: "Contact"</item>
                       <item>12. Say You, Say Me [Lionel Richie]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"Submissions"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. Lecture; October Group</item>
                       <item>2. Rite Of Spring; Allen Herman Productions</item>
                       <item>3. Jazzical [Mike Garson]</item>
                       <item>4. Steve Allen Songs, Vol. IV</item>
                       <item>5. Gerard Kenny Songs For Bob Fosse</item>
                       <item>6. Joni (?) Groves/ Commercial Demos</item>
                       <item>7. Peech Boys; Ray Parker; Bazz; Grace Jones</item>
                       <item>8. Happy Birthday To Me [Hugh Martin and Timothy Gray]</item>
                       <item>9. Willpower</item>
                       <item>10. Jack West</item>
                       <item>11. The Lion, The Witch and The Wardrobe [Tierney-Drachman]</item>
                       <item>12. Vaudeville Memories [Jeff Steele]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"Miscellaneous, including Chayefsky Emmy Tribute and
           Interviews"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. Wilbur Stump/Interview; Performance</item>
                       <item>2. same</item>
                       <item>3. Emmy Award Tribute To Paddy Chayefsky</item>
                       <item>4. Interview 5/15/86 With Grubb</item>
                       <item>5. Fosse/NYU Filmmakers</item>
                       <item>6. Frederick Gaymon/Tom Baumgartner</item>
                       <item>7. Tim Collins; Interview/Performance</item>
                       <item>8. Charlotte and Harold Greene</item>
                       <item>9. Cassette #3: "Down Home Diddley Dum" to "Mabel"</item>
                       <item>10. Percussion IV</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"Show, Research, Miscellaneous"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. Monologue: Tag Standup</item>
                       <item>2. Songs By Bob Christianson</item>
                       <item>3. Lenny Bruce Is Out Again</item>
                       <item>4. Grand Opening [Spencer/Calloway]</item>
                       <item>5. The Best Of Lenny Bruce</item>
                       <item>6. Introspection/Mike Alterman</item>
                       <item>7. Chicago, 1974: Announcement of Bob's Illness</item>
                       <item>8. Who's Sorry Now</item>
                       <item>9. Christmas Songs</item>
                       <item>10. Heat: Music, 1986</item>
                       <item>11. Not Labeled</item>
                       <item>12. Not labeled</item>
                       <item>13. Joyce Ford: 6 tapes</item>
                       <item>14. Lenny Bruce Interviews</item>
                       <item>15. Lenny Bruce: The Berkeley Concert</item>
                       <item>16. Things Are Getting Better [Van Joyce]</item>
                       <item>17. Not Labeled</item>
                       <item>18. "Joe's Song" Demo [Jeffrey Townsend]</item>
                       <item>19. "After You've Gone" [Benny Goodman]</item>
                       <item>20. Lenny Bruce: Thank You, Masked Man</item>
                       <item>21. Lenny Bruce In Concert</item>
                       <item>22. Lenny Bruce: American</item>
                       <item>23. Essential Lenny Bruce Politics</item>
                       <item>24. Mahoganny #1</item>
                       <item>25. Mahoganny #2</item>
                       <item>26. Mahoganny #3</item>
                       <item>27. Mephistopheles</item>
                       <item>28. <emph render="italic">Pippin</emph> Commercial</item>
                       <item>29. Ken Laub Music</item>
                       <item>30. Shel Silverstein; The Devil &amp; Billy Markham; Billy Markham's
              Dream</item>
                       <item>31. Mike Shurtleff</item>
                       <item>32. <emph render="italic">All That Jazz</emph>: Stand-Up
              Monologue</item>
                       <item>33. Jennifer O'Neil</item>
                       <item>34. The Ragtime Blues</item>
                       <item>35. Sirens</item>
                       <item>36. Not Labeled</item>
                       <item>37. Edited Bach</item>
                       <item>38. Not Labeled</item>
                       <item>39. Sony Demo Cassette</item>
                       <item>40. TV Commercial</item>
                       <item>41. '76 Arrangement</item>
                       <item>42. Not Labeled</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"All That Jazz, Dancin', Sweet Charity"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. <emph render="italic">All That Jazz</emph>: All Selected
              Takes</item>
                       <item>2. <emph render="italic">Rhythm Of Life</emph>: Original Cast</item>
                       <item>3. <emph render="italic">Sweet Charity</emph> I: La Chandler Pavilion
              8/17/85 Matinee</item>
                       <item>4. <emph render="italic">All That Jazz</emph>: All Selected
              Takes</item>
                       <item>5. <emph render="italic">All That Jazz</emph>: Take Off With
              Us...etc.</item>
                       <item>6. <emph render="italic">All That Jazz</emph>: 13-41;42-60, all
              takes</item>
                       <item>7. <emph render="italic">All That Jazz</emph>: Take Off With Us,
              Interlude, etc.</item>
                       <item>8. <emph render="italic">All That Jazz</emph>: ye, Bye Life</item>
                       <item>9. <emph render="italic">All That Jazz</emph>: Hospital Medley, Parts
              2,3,4</item>
                       <item>10. There's No Business ...[Ethel Merman]</item>
                       <item>11. <emph render="italic">All That Jazz</emph>: Hospital Medley, Part
              1 11/23/78</item>
                       <item>12. Act III</item>
                       <item>13. <emph render="italic">Sweet Charity</emph> II: Sat. Mat.,
              8/17/85</item>
                       <item>14. <emph render="italic">Sweet Charity</emph>: I'm The Bravest
              Individual</item>
                       <item>15. Linda Clifford: If My Friends Could See Me Now</item>
                       <item>16. <emph render="italic">All That Jazz</emph>: Medley: After You're
              Gone, Etc.</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"Star 80, Little Me, Grind, Goodbye People, I'm Not
           Rappaport, STAR 80"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. Grind I</item>
                       <item>2. Grind II</item>
                       <item>3. <emph render="italic">Little Me</emph>: The Backstage Story</item>
                       <item>4. Song &amp; Dance, Nov. 85, Act II</item>
                       <item>5. <emph render="italic">Star 80</emph>: Underscore</item>
                       <item>6. Ladd Co: Star 80</item>
                       <item>7. The Fosse/Rees Tape, 12/31/81</item>
                       <item>8. <emph render="italic">Star 80</emph>, French,
              Warner-Columbia</item>
                       <item>9. I'm Not Rappaport</item>
                       <item>10. Goodbye People, Music Cues</item>
                       <item>11. Goodbye People, 5/4/79</item>
                       <item>12. Editing Room, Sound</item>
                       <item>13. I'm Not Rappaport, Act I</item>
                       <item>14. <emph render="italic">Star 80</emph>, Editing, Television
              soundtrack</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">"Big Deal Research"</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1. Roman Dicare</item>
                       <item>2. Cookie Van House/Louie Anderson</item>
                       <item>3. Dee Cullin</item>
                       <item>4. Lloyd Pritchard/Rex Purejoy</item>
                       <item>5. Frederick Gaymon/Tom Baumgartner</item>
                       <item>6. Erwin Laitala/Ted Denesha</item>
                       <item>7. J.D. Steele Gospel Singers/Gary Neal (Barker)</item>
                       <item>8. Matthew Kirby/Kirby Playing Dulcimer</item>
                       <item>[Including duplicates of above:]</item>
                       <item>1. Flash Bulbs Igniting</item>
                       <item>2. Grandfather Clock</item>
                       <item>3. Watch Ticking I</item>
                       <item>4. <emph render="italic">Big Deal</emph>/:30 Scratch Track</item>
                       <item>5. Making Whoopee [Ray Charles]</item>
                       <item>6. Well Git It</item>
                       <item>7. Get It [Trombone]</item>
                       <item>8. Ike</item>
                       <item>9. Are You Having Any Fun</item>
                       <item>10. Loretta Devine Vocal Demo</item>
                       <item>11. Not Labeled</item>
                       <item>12. Harry</item>
                       <item>1. Charlie My Boy</item>
                       <item>2. Courtroom Rap</item>
                       <item>3. Ain't We Got Fun</item>
                       <item>4. Rumble</item>
                       <item>5. Sittin' On Top</item>
                       <item>6. Ain't We Got Fun/Stoptime</item>
                       <item>7. Button Up</item>
                       <item>8. Happy Days</item>
                       <item>9. <emph render="italic">Big Deal</emph> 2/18/86</item>
                       <item>10. Rehearsal Run-Through</item>
                       <item>11. Ain't We Got Fun</item>
                       <item>12. Rap</item>
                       <item>13. I Got A Feelin'</item>
                       <item>14. Rainbow Rider II/Ain't She Sweet</item>
                       <item>1. For No Good Reason</item>
                       <item>2. Gigolo</item>
                       <item>3. Cherries</item>
                       <item>4. Pick Yourself Up</item>
                       <item>5. Scratch Song Demos</item>
                       <item>6. <emph render="italic">Chicago</emph> [Streetcar]</item>
                       <item>7. For No Good</item>
                       <item>8. Beat Me Update 11/8</item>
                       <item>9. For No Good Reason</item>
                       <item>10. Rob. Sounds 1</item>
                       <item>11. Music Goes 'Round</item>
                       <item>12. Me And My Shadow</item>
                       <item>13. T'aint 1 &amp; 3</item>
                       <item>14. A'int We Got</item>
                       <item>15. Who-Zis</item>
                       <item>1. Me And My Shadow/T'aint What Cha Do</item>
                       <item>2. Me And My Shadow/T'aint What Cha Do</item>
                       <item>3. Camera Stealing/Beat Me Daddy/Well Git It</item>
                       <item>4. Peter Allen: Song He Wrote For <emph render="italic">Big
                 Deal</emph>
                       </item>
                       <item>5. Finger-Rhythms</item>
                       <item>6. Robbery [Rhythm]</item>
                       <item>7. Music Goes II</item>
                       <item>8. Westside Rumble</item>
                       <item>9. Daddy</item>
                       <item>10. Beat Me [Vocal]</item>
                       <item>11. Synth Percussion</item>
                       <item>12. Harry</item>
                       <item>13. Ain't We Got Fun/Tap Dance</item>
                       <item>14. Beat Me Breakdown</item>
                       <item>15. Ain't - Sound Tracks</item>
                       <item>1. <emph render="italic">Big Deal</emph>/2 Spots/Boston</item>
                       <item>2. Happy Days</item>
                       <item>3. Beat Me Daddy! :30</item>
                       <item>4. New Beat Me, Part III</item>
                       <item>5. New Camera</item>
                       <item>6. Robbery To End Of Bows</item>
                       <item>7. Everybody - Baby - New Versions</item>
                       <item>8. Beat Me [Improv] And New Beat Me</item>
                       <item>9. Now's The Time</item>
                       <item>10. Robbery</item>
                       <item>11. Million Dollar</item>
                       <item>12. Beat Me Revised</item>
                       <item>13. Ain't She [Popcorn]</item>
                       <item>14. Shadows [Rhythm]</item>
                       <item>15. Robbery 2/12</item>
                       <item>16. Roosevelt First Inaugural Address 3/4/33</item>
                    </list>
                 </item>
              </list>
           </item>
           <item>
              <emph render="underline">
                 <emph render="bold">Videocassette Tapes</emph>
              </emph>
              <list listtype="unordered" mark="circle">
                 <item>
                    <emph render="bold">General</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Note: All materials are located in the Motion Picture, Broadcasting,
              and Recorded Sound Division (MBRS) of the Library of Congress. As
              available, LC record numbers are indicated next to each videocassette
              tape. Unless otherwise marked, these are all VHS format videocassettes.
              Identification has been taken from labels. The following are not
              necessarily grouped by their relation to a particular production, but
              alphabetically, according to labeling. Several pieces of correspondence
              and title lists pertaining to videotapes are filed elsewhere. These
              videocassette tapes are NOT cross referenced with individual
              productions.]</item>
                       <item>[Note: The following 3/4" videotapes are editing materials for the
              Sheehan-Tele-Scenes production (information is taken directly from
              labels.)]</item>
                       <item>
                          <emph render="italic">All That Jazz</emph> [marked 3/4/85, television
              version, "property of Columbia Pictures-BF"]</item>
                       <item>
                          <emph render="italic">All That Jazz</emph> [20th Century-Fox; RT: 123) (2
              copies)</item>
                       <item>Debbie Allen Presentation, 2/8/85 [3/4"]; LC Record #95-514438</item>
                       <item>The American Dance Machine: A Celebration of Broadway Dance</item>
                       <item>Fred Astaire Special and Swing Time</item>
                       <item>At The Movies, Program # 209:review of <emph render="italic">Star
                 80</emph> [3/4"]</item>
                       <item>Beat Me Daddy, Tony Awards</item>
                       <item>Belmont Commercial (Gwen Verdon); LC Record #95-514365</item>
                       <item>
                          <emph render="italic">Big Deal</emph> #1</item>
                       <item>
                          <emph render="italic">Big Deal</emph> #2</item>
                       <item>
                          <emph render="italic">Big Deal</emph>: "Where There's Smoke" [:30]; LC
              Record #95-514672</item>
                       <item>
                          <emph render="italic">Big Deal</emph>: "Where There's Smoke"
              [4/24/86]</item>
                       <item>
                          <emph render="italic">Big Deal</emph>, compilation of rehearsal stories
              [WABC-TV/Ch. 7; CNN/Showbiz Today; Entertainment Tonight]</item>
                       <item>
                          <emph render="italic">Big Deal</emph> Boston TV Coverage: Entertainment
              Tonite opening night feature; WCVB-TV: Review and feature; WBZ-TV, Review
              and feature; WNEV-TV, Review and feature; WCVB-TV, "Good Day Boston,"
              with Loretta Devine; WBZ-TV "Live on Four" with Cleavant Derricks;
              WGBH-TV, "10 PM News," Kevin Kelly interview with Bob Fosse; WCVB-TV:
              "Good Day Boston" with Alan Weeks, WCVB-TV, "City Line with Loretta
              Devine and Alan Weeks</item>
                       <item>
                          <emph render="italic">Big Deal On MaDonna Street</emph>; LC Record
              #95-514673</item>
                       <item>"Broadway! A Musical History with Ron Husman" Demo tape</item>
                       <item>"Broadway! A Musical History," Vol. 1-5, 5 tapes</item>
                       <item>
                          <emph render="italic">Cabaret</emph> [commercial release] [3
              copies]</item>
                       <item>
                          <emph render="italic">Cabaret</emph> [MGM/CBS]</item>
                       <item>The Cannes Show, 1980; The Oscar Race, 1980 [3/4"]</item>
                       <item>
                          <emph render="italic">Chicago</emph>, Ash Ledonne Fisher, Vol. 1,
              4/26/85</item>
                       <item>
                          <emph render="italic">Chicago</emph>, Gwen and Chita [Gwen Verdon and
              Chita Rivera, television commercial]; LC Record #95-514269</item>
                       <item>
                          <emph render="italic">Chicago</emph>, television commercial; LC Record
              #95-514270</item>
                       <item>
                          <emph render="italic">Chicago</emph>, television commercial; LC Record
              #95-514355</item>
                       <item>The Clowns, Fellini</item>
                       <item>Cole, Jack: Jack Cole Film Dances</item>
                       <item>"Cool Hand Luke," Dr. Pepper, 5/8/81, Gwen Verdon; LC Record
              #95-514433</item>
                       <item>"Cool Hand Luke, 5/8/81; LC Record #95-514919</item>
                       <item>
                          <emph render="italic">Damn Yankees</emph> [Warner Home Video]</item>
                       <item>Dance "Enamoranzia"; LC Record #95-514267</item>
                       <item>Dance In America: "Romeo and Juliet," San Francisco Ballet</item>
                       <item>Dance Numbers By American Choreographers [Gwen Verdon's tape]<list listtype="unordered" mark="circle">
                             <item>
                                <emph render="italic">Oklahoma!</emph> [Agnes de Mille: Dream
                    ballet excerpts (Film - 1955) (Television Special 1979) Biography
                    of Jerome Robbins]</item>
                             <item>
                                <emph render="italic">Fancy Free</emph> - excerpt (1980)</item>
                             <item>
                                <emph render="italic">West Side Story</emph> (film, 1961); Dance at
                    the Gym, Cool</item>
                             <item>
                                <emph render="italic">Seven Brides For Seven Brothers</emph>;
                    (Michael Kidd) (film, 1954); Hoedown</item>
                             <item>
                                <emph render="italic">Hello, Dolly!</emph> (Michael Kidd, 1969);
                    Dancing</item>
                             <item>
                                <emph render="italic">On The Riviera</emph> (Jack Cole, 1951);
                    Finale</item>
                             <item>
                                <emph render="italic">Kiss Me Kate</emph> (Pan Hermes and Bob
                    Fosse) (film, 1953); From This Moment On</item>
                             <item>
                                <emph render="italic">My Sister Eileen</emph> (Bob Fosse, 1955);
                    Alley Dance; Give Me a Band</item>
                             <item>
                                <emph render="italic">Pajama Game</emph> (Bob Fosse, 1958); Steam
                    Heat</item>
                             <item>
                                <emph render="italic">Damn Yankees</emph> (Bob Fosse, 1958; Mambo;
                    Two Lost Souls</item>
                             <item>Les Girls (Jack Cole, 1957); Why Am I So Gone...?</item>
                             <item>
                                <emph render="italic">Cabaret</emph> (Bob Fosse, 1972); Mein
                    Herr</item>
                             <item>Movie, Movie (Michael Kidd, 1977); Torchin' for Bill</item>
                             <item>Showstoppers - A Chorus Line (Michael Bennett, television,
                    1980); Music and the Mirror</item>
                             <item>
                                <emph render="italic">The Little Prince</emph> (Bob Fosse, 1974);
                    Snake in the Grass</item>
                             <item>
                                <emph render="italic">Dancin'</emph> (Bob Fosse, 1977); Sing Sing
                    Sing</item>
                             <item>
                                <emph render="italic">All That Jazz</emph> (Bob Fosse, 1979); On
                    Broadway; Everything Old Is New Again</item>
                          </list>
                       </item>
                       <item>David And Bathsheba</item>
                       <item>David And Bathsheba [CBS Fox]</item>
                       <item>Dear John 3/9/89</item>
                       <item>Derricks, Cleavant, "Moscow on the Hudson" [excerpts]</item>
                       <item>Dick Cavett Show, with Bob Fosse (2 half hour programs)</item>
                       <item>The Dinah Shore Show [Nicole Fosse, Gwen Verdon]</item>
                       <item>Dorothy Stratten: The Untold Story</item>
                       <item>Fame [1015 The Center]</item>
                       <item>The Farmer Takes A Wife, 1953</item>
                       <item>Ferry, David: Audition tape [3/4"]</item>
                       <item>"Bob Fosse: Steam Heat," WNET/Thirteen, Great Performances, Dance in
              America, Episode # 1541, 1/25/90</item>
                       <item>Fosse, London Television</item>
                       <item>Fosse: Various Dances</item>
                       <item>Fosse Dances: <emph render="italic">Kiss Me Kate</emph>; <emph render="italic">Give A Girl A Break</emph>; <emph render="italic">My
                 Sister Eileen</emph>? "Fox Rock" [3/4"]</item>
                       <item>From Raquel [Welch] With Love [3/4"]</item>
                       <item>Gibb, Andy - segments: From Olivia Newton-John special and hosting
              "The Midnight Special," Bob Fosse presentation [3/4 "]</item>
                       <item>Gimme A Break [Gwen Verdon]</item>
                       <item>Good Morning, NY, Peter Bogdanovich interview (at 361 ft.)</item>
                       <item>Hall, Arsenio, audition tape [3/4"]</item>
                       <item>Hall of Fame, Television</item>
                       <item>Hamilton Place Theatre, 5/81, selected interior shots [3/4"]</item>
                       <item>Hang Up The Phone, directed by Howie Deutsch, 4/19/84 [3/4"]</item>
                       <item>Hello Hollywood: Bob Fosse (Italian, 2/1/88)</item>
                       <item>Hello Hollywood, Bob Fosse, 3/24/81</item>
                       <item>Hello Hollywood, Bob Fosse, 4/23/81</item>
                       <item>Hello Hollywood, Qui Broadway, Rai Italian television [3/4"]</item>
                       <item>Bob Hope Special, 10/14/68 [Gwen Verdon dances; original reel #4]
              [3/4"]; LC Record #95-514453</item>
                       <item>Hotel, 5/18/89</item>
                       <item>Hubbard Street Dance, 6/14/85</item>
                       <item>Invitation To The Wedding, Part 1 of 2 [3/4" tape]</item>
                       <item>Invitation To The Wedding, Part 2 of 2 [3/4" tape]</item>
                       <item>Island dailies [reels 40, 41, 43, 44, 45, MOS reels 42. 46. 47
              Pic/Tk]</item>
                       <item>Kevin Kelly - Bob Fosse, 2/24/86</item>
                       <item>Kids, Inc., show #216, starring Gwen Verdon: "Grandma Won't You Dance
              With Me"</item>
                       <item>
                          <emph render="italic">Legs</emph>, ABC TV movie [Beta]</item>
                       <item>
                          <emph render="italic">Lenny</emph>, with Wilhemina label</item>
                       <item>
                          <emph render="italic">Lenny</emph> [Bob Fosse, 8/25/80]</item>
                       <item>
                          <emph render="italic">Lenny</emph> [United Artists]</item>
                       <item>
                          <emph render="italic">Lenny</emph>, Part I [3/4"]</item>
                       <item>
                          <emph render="italic">Lenny</emph>, Part II [3/4"]</item>
                       <item>Life On Earth, Episode 12</item>
                       <item>Live At Five, Mariel Hemingway Interview [52 ft.- 85 ft.] (Same tape
              as Today Show with Bob Fosse)</item>
                       <item>
                          <emph render="italic">Liza With A Z</emph>, 1/5/87</item>
                       <item>
                          <emph render="italic">Liza With A Z</emph> [film to tape transfer,
              11/13/89]</item>
                       <item>Love Connection II</item>
                       <item>Love Connection III</item>
                       <item>Magnum, PI [10/31/85 (1039 ft.); 2/11/89]</item>
                       <item>Magnum, PI [final]</item>
                       <item>M*A*S*H, guest star Gwen Verdon: "That's Show Biz"; LC Record
              #95-514919</item>
                       <item>Meisner, Sandy, Documentary [excerpts]</item>
                       <item>Motown Returns To The Apollo [NBC TV, May, 1985]: 000: opening, 5.30:
              Medley - Tall, Tan, Teasin', 18.50: Gregory Hines, 23.25: Tap - film
              clips, 26.35: Hoofers</item>
                       <item>Music Of The Big Bands</item>
                       <item>Music Moves Me, Ann Reinking and Gary Chryst; Liza Minnelli
              interview</item>
                       <item>My Wicked Wicked Ways [TV movie]</item>
                       <item>Night Of 100 Stars, performance date 2/17/85 [2 copies]</item>
                       <item>Noxema Shaving Cream Commercial, with Farah Fawcett; LC Record
              #95-514364</item>
                       <item>On Stage America [starts at 165', Ben Veeren segment ends at
              242']</item>
                       <item>One Of A Kind Show, Frankie Klein and Manuel Arte</item>
                       <item>Paul's Case (American Short Stories Series), with Eric Roberts
              [audition material for <emph render="italic">Star 80</emph>)
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 1, 9/19/85</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 2, 9/19/85</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 3, 9/19/85</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 4, 9/19/85</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 5, 9/19/85</item>
                       <item>
                          <emph render="italic">Pennies From Heaven</emph>, Producer's Circle,
              Parts 1 and 2, Episode 6, 9/19/85</item>
                       <item>
                          <emph render="italic">Pippin</emph>, the University of Michigan</item>
                       <item>
                          <emph render="italic">Pippin</emph>, "Gisela, Fastrada" (Gisela is a
              German nightclub) [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>: His Life and Times,
              Sheehan-Tele-Scenes, 1981</item>
                       <item>
                          <emph render="italic">Pippin</emph> presentation, David Sheehan,
              9/81</item>
                       <item>
                          <emph render="italic">Pippin</emph> presentation, David Sheehan,
              9/81</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part 1 of 2, Address code
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part 2 of 2, Address code
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part II, with Fosse fixes by
              Doby/Acito, 12/9/81 [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part II, with Fosse fixes by
              Doby/Acito, 12/9/81 [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, 11/1/81 [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part I, Final as of 11/22/81
              [3/4"]</item>
                       <item>Fast Lane Living, Final, 4/3/81 [marked Sheehan Telescenes, "yet
              another cutting style"] [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part I, Final, 11/19/81
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, K. Doby's work [including Doby's
              letter to Bob Fosse] [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Act I off line, master, 9/14/81
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, first hour, 10/7/81 [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, 10/8/81, 1" on line with off line
              inserts [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, Part I out takes, excerpt of
              pull-ups [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph> Finale, 12/9/81, according to Bob
              Fosse notes executed by Doby and Acito [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, 9/2/81, Scene 1, 2nd cut
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, 10/30/81, Right Track and Finale
              [3/4"]</item>
                       <item>
                          <emph render="italic">Pippin</emph>, 8/30/81, 1st cut, open title
              sequence and Magic to do, corner of the sky [3/4"]</item>
                       <item>Playmate Video Magazine Interview [VHS]</item>
                       <item>Reinking, Ann, Casting, 11/3/75 [3/4"]; LC Record #95-514676</item>
                       <item>Reinking, Ann, Demo Tape, 30 min., 1/11/83 [3/4"]; LC Record
              #95-514675</item>
                       <item>Richie, Lionel, "Dancing on the Ceiling," dir: Stanley Donen</item>
                       <item>Jerome Robbins, Live from Studio 8H, 7/2/198?</item>
                       <item>Other Dances (3 numbers from 3 For The Show, Jack Cole; Grable)</item>
                       <item>Richard Romanus, "Ten Speed and Brown Shoe," audition tape
              [3/4"]</item>
                       <item>Saturday Show, Miss Playmate and Miss USA [3/4"]</item>
                       <item>Gene Shalit Interview with Bob Fosse, 1/19/85 [and Love Connection
              IV]</item>
                       <item>Gene Shalit Interview with Eric Roberts [3/4"]</item>
                       <item>Barbara Sharma Demo Tape</item>
                       <item>David Sheehan, 3/24/81</item>
                       <item>David Sheehan, Cannes [3/4"]</item>
                       <item>Showdance, the BBC Late Show, 1991</item>
                       <item>Showtime, November Take One Profile of Bob Fosse, interviewer: Laura
              Davis [3/4 "]</item>
                       <item>Showtime In Cannes, with David Sheehan, 1980 [3/4"]</item>
                       <item>Showtime In Cannes, Bob Fosse, 8/25/80</item>
                       <item>Showtime In Hollywood #2, David Sheehan, 10/80 [3/4"]</item>
                       <item>Showtime In Hollywood #3, David Sheehan, 12/15/80 [3/4"]</item>
                       <item>Showtime In Hollywood #6, David Sheehan with Bob Fosse, Jane Fonda,
              Candice Bergen, Ann Reinking [3/4"]</item>
                       <item>Showtime In Hollywood #22, David Sheehan [3/4"]</item>
                       <item>Joel Siegel, Oscars, 4/14/80 [3/4"]</item>
                       <item>Joel Siegel, Oscar Show, Bob Fosse, 8/25/80</item>
                       <item>Smith, Norman: "Reel Life" [3/4"]</item>
                       <item>The South Bank Show, Bob Fosse, 3/26/81</item>
                       <item>Spotlight! [Gwen Verdon, Guest]</item>
                       <item>SRO: Paris Cabaret, 11/7/80 [3/4"]</item>
                       <item>Star Award, Michael Bennett, 1988 ["Reflections" by Bob Avian,
              Presentation Version]</item>
                       <item>Star Award, Bob Fosse, 1988: "Reflections, by Gwen Verdon"</item>
                       <item>
                          <emph render="italic">Star 80</emph> [Ladd/Warner]</item>
                       <item>
                          <emph render="italic">Star 80</emph>: WABC-TV, ABC NET, Good Morning
              America [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, "Music cues for recording sessions"
              (4) [3/4"] marked on cover "for re-recording, use as blanks]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, "Trailer composite, 8/25/83"</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting: Tracy and Kirsten
              [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting: N.Y. "Betty:" Sheila
              Kennedy, Courtney Carrington [VHS]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting: NY "Betty:" Sheila
              Kennedy, Courtney Carrington [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting: Jennifer Coofe (Betty)
              [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, "Eileen" casting, 4/13/82 (2) [3/4]
              (tape label reads "Tracie &amp; Nicole, 4/13/82")</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting, "Eileen" Test, Central
              Park, Quogue, with Lisa</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting, "Eileen" Test, Nicole's
              interview and Kathy, #3, 4/13/82 [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Casting, "Eileen" Test, Kathy
              cont., #4, 4/13/82 [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, rough cut videotape edit, part
              1</item>
                       <item>
                          <emph render="italic">Star 80</emph>, rough cut videotape edit, part
              2</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Edited Version, Temp Music, and
              Full 3 Min. Version [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>, Mariel Hemingway Interview, 9:00
              am, 2/3/82; Hefner Interview Ch. 7/ABC, 7:30, 2/2/82</item>
                       <item>
                          <emph render="italic">Star 80</emph>, WNBC-TV, NBC NET, Today, Nov. 16,
              Wed., 7am [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>: Clips 40-45; publicity clips, "New"
              [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>: Television excerpts, 40-46, "Old"
              [3/4"]</item>
                       <item>
                          <emph render="italic">Star 80</emph>: Television excerpts, 10/22/83
              [VHS]</item>
                       <item>"Steps," Dr. Pepper, 5/8/81, Gwen Verdon</item>
                       <item>Stratten, Dorothy, 5/6/82, Canadian Television</item>
                       <item>Stratten, Dorothy: BCTV [3/4"]</item>
                       <item>Stratten, Dorothy: BCTV News: "Playmate Murdered," and "Stratten Film"
              [3/4"]</item>
                       <item>Stratten, Dorothy: 1980 Playboy Playmate of the Year Press
              Luncheon</item>
                       <item>Stratten, Dorothy: 1980 Playmate of the Year Press Luncheon, with time
              code [3/4"]</item>
                       <item>Stratten, Dorothy: Tonite Show segment [3/4"]</item>
                       <item>Sweeney Todd, Part 1, [3/4"]</item>
                       <item>Sweeney Todd, Part 2, 3/12/82 [3/4"]</item>
                       <item>Sweeney Todd, Part 3, [3/4"]</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph>, Part 1, Steve David</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph>, Part 2, Steve David</item>
                       <item>Backstage at <emph render="italic">Sweet Charity</emph>, 1986; LC
              Record #95-514778</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph>, PBS version</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph> - 1</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph>, Minskoff Theatre, 10/27/86
              [:30, <emph render="italic">Sweet Charity</emph>; :10 <emph render="italic">Sweet Charity</emph>]; LC Record #95-514704</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph> (Bob Fosse, reel 1,
                 5/22/85)<list listtype="unordered" mark="circle">
                             <item>1) "Big Spender"</item>
                             <item>2) "Frug"</item>
                             <item>3) "If My Friends Could See Me Now"</item>
                             <item>4) "There's Gotta Be Something Better Than This"</item>
                          </list>
                       </item>
                       <item>
                          <emph render="italic">Sweet Charity</emph> (Bob Fosse, reel 2,
                 5/22/85)<list listtype="unordered" mark="circle">
                             <item>1) "Rhythm of Life"</item>
                             <item>2) "Brass Band"</item>
                             <item>3) "I Love to Cry at Weddings"</item>
                          </list>
                       </item>
                       <item>
                          <emph render="italic">Sweet Charity</emph> Commercial [30 sec]; Brass
              Band [10 sec]; [Macy's Parade]; LC Record #95-514772</item>
                       <item>"Taste the Music" Frank Langella audition tape [<emph render="italic">All That Jazz</emph>] [3/4"]; LC Record #95-514358, #95-514357,
              #95-514359</item>
                       <item>The Tempest, 5/27/80; LC Record #95-514268</item>
                       <item>That's Entertainment, Part II [MGM/CBS] (2)</item>
                       <item>
                          <emph render="italic">Thieves</emph>
                       </item>
                       <item>Today Show, Bob Fosse interview [5.5 ft.-49 ft.] (tape also including
              Mariel Hemingway on Live At Five)</item>
                       <item>Tomorrow Show, Dorothy Stratten [after 400 ft.]</item>
                       <item>Tony Awards, Bob Fosse and Gwen Verdon</item>
                       <item>Tony Awards, Bob Fosse, 1980, American Theatre Wing</item>
                       <item>Tony Awards, 1986</item>
                       <item>Trapper, 3/30/85 [Trapper 0-607; Bill Boggs, 608-659]</item>
                       <item>TV Hall Of Fame</item>
                       <item>Unidentified [3/4"]</item>
                       <item>Vasquez, Antonia: Pfizer/Coty, Emeraude, "One Man, One Fragrance"
              [3/4"]; LC Record #95-514362</item>
                       <item>"Verdon"</item>
                       <item>Verdon [Bob Fosse, 3/24/81]</item>
                       <item>Gwen Verdon's Dance Numbers [Bob Fosse, 3/31/81]</item>
                       <item>Viewpoint: "Cameras, Courts, Justice," 5/24/84, Part 1 [3/4"]</item>
                       <item>Viewpoint: "Cameras, Courts, Justice," 5/24/84, Part 2 [3/4"]</item>
                       <item>Craig Wasson, "Nights at O'Rears" audition tape [3/4"]</item>
                       <item>Craig Wasson, "Four Friends" audition tape [3/4"]</item>
                       <item>Webster, 1/10/86; Equalizer, 2/19/86; Webster</item>
                       <item>York, Michael: Screen test [3/4"]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">WNET/13 Film And Videotape Materials [Used For "Bob Fosse:
           Steam Heat"]</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Note: All materials are located in the Motion Picture, Broadcasting,
              and Recorded Sound Division (MBRS) of the Library of Congress. As
              available, LC record numbers are indicated next to each film, video, or
              sound recording. All information is taken from labeling on the materials
              themselves; these materials are not cross listed with individual
              productions.]</item>
                       <item>WNET/Thirteen, Great Performances Dance In America: Bob Fosse Various
              Dance Routines [3/4 in. videocassette, master]; LC Record
              #95-514847</item>
                       <item>Breakfast Time "Bob Fosse" [3/4 in. videocassette]</item>
                       <item>Entertainment Tonight: Fosse Obit Footage [label on tape; label on
              case also says "Big Deal outtakes"] [3/4 in. videocassette, KCS-20]; LC
              Record #95-514674</item>
                       <item>Bob Fosse: American Express Commercial [1 in. videotape]; LC Record
              #95-514356</item>
                       <item>
                          <emph render="italic">Pippin</emph> Commercial (Through ADO) [1 in.
              videotape]</item>
                       <item>Entertainment Tonight: Bob Fosse Segments [4 cut spots] 1 in.
              videotape]</item>
                       <item>Dance In America: Bob Fosse: Steam Heat Entertainment Tonight - 4 cut
              segments</item>
                       <item>B-Roll, Split audio tracks, 1/16/90 [1 in. videotape]</item>
                       <item>Wogan: Bob Fosse Interview [1 in. videotape]</item>
                       <item>Fosse/Meiser, Dance In America workpic transfer w/audio &amp; Nagra
              audio only [1 in. videotape]</item>
                       <item>9/10/85 am: Fosse on <emph render="italic">Lenny</emph>, 9/24/87 pm:
              Fosse Obit [1 in. videotape]</item>
                       <item>
                          <emph render="italic">Sweet Charity</emph>, featurette, Part 1 of 3 [1
              in. videotape, film transfer master]</item>
                       <item>Cavalcade Of Stars [1 in. videotape]</item>
                       <item>
                          <emph render="italic">Affairs Of Dobie Gillis</emph>, <emph render="italic">Give A Girl A Break</emph> [clip reel] [1 in.
              videotape]</item>
                       <item>
                          <emph render="italic">Pajama Game</emph>: Clip [1 in. videotape]</item>
                       <item>
                          <emph render="italic">The Little Prince</emph>, <emph render="italic">Sweet Charity</emph>, <emph render="italic">Cabaret</emph>, [Sections
              From Laserdisc] [1 in. videotape]</item>
                       <item>
                          <emph render="italic">Damn Yankees</emph>: Selected Clips [1 in.
              videotape]</item>
                       <item>
                          <emph render="italic">My Sister Eileen</emph>: Selected Clips [1 in.
              videotape]</item>
                       <item>Tomorrow Show: Bob Fosse [1 in. videotape]</item>
                       <item>
                          <emph render="italic">Dancin'</emph>: <emph render="italic">Dancin'</emph> Road Show :30 [1 in. videotape]</item>
                       <item>Single Tape: Bob Fosse <emph render="italic">Steam Heat</emph>
                          <list listtype="unordered" mark="circle">
                             <item>1) Title test</item>
                             <item>2) <emph render="italic">Dancin'</emph>
                             </item>
                             <item>3) <emph render="italic">Chicago</emph> commercial [1 in.
                    videotape]</item>
                          </list>
                       </item>
                       <item>Single Tape: <emph render="italic">Kiss Me Kate</emph>, Indian Dance,
              Shoeless Joe, Senior Loco, All That Jazz [1 in. videotape] From box
              marked: "I Inch Videotape, Gwen Verdon &amp; Nicole Fosse Interview,
              9/89, Film To Tape": Green Fuji videotape cases numbered 20-30 [11
              cases]</item>
                       <item>Your Hit Parade, 10/7/50 [1 in. videotape]</item>
                       <item>We The People, 11/24/50 [1 in. videotape]</item>
                       <item>Burns And Allen [1 in. videotape]</item>
                       <item>Garry Moore Show [1 in. videotape]</item>
                       <item>
                          <emph render="italic">Star 80</emph> Trailer [1 in. videotape]</item>
                       <item>From box marked "#1, Film Neg, Camera A, Interview with Gwen Verdon
              and Nicole Fosse, 9/89;" and 16 mm film negatives</item>
                       <item>From box marked "#2, Film Neg, Camera B, Interview with Gwen Verdon
              and Nicole Fosse, 9/89;" and 16mm film negatives</item>
                       <item>Dance In America audio tape:<list listtype="unordered" mark="circle">
                             <item>1) Audiotape of Gwen Verdon Interview, 9/6/89, Roll #1</item>
                             <item>2) "Raw Audio" of Gwen Verdon Interview, 9/6/89, Roll #2</item>
                             <item>3) "Raw Audio" of Gwen Verdon Interview, 9/6/89, Roll #3</item>
                             <item>4) "Raw Audio" of Gwen Verdon Interview, 9/6/89, Roll #4</item>
                             <item>5) "Raw Audio" of Gwen Verdon Interview, 9/7/89, Roll #5</item>
                             <item>6) "Raw Audio" of Gwen Verdon Interview, 9/7/89, Roll #6</item>
                             <item>7) "Raw Audio" of Gwen Verdon Interview, 9/7/89, Roll #7</item>
                             <item>8) "Raw Audio" of Gwen Verdon Interview, 9/7/89, Roll #8</item>
                          </list>
                       </item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">WNET/13 Research: Press Books</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) Fosse: Transcripts<list listtype="unordered" mark="circle">
                             <item>Re: Fred Astaire</item>
                             <item>Boston <emph render="italic">Big Deal</emph> footage</item>
                             <item>Capezio Award</item>
                             <item>Dance Magazine Award</item>
                             <item>Dick Cavett Show</item>
                             <item>Nicole Fosse Interview</item>
                             <item>Re: Sanford Meisner</item>
                             <item>Joel Siegel Interview</item>
                             <item>Sheehan Interviews</item>
                             <item>
                                <emph render="italic">Sweet Charity</emph> Featurette</item>
                             <item>Shalit Interview</item>
                             <item>
                                <emph render="italic">Star 80</emph> Trailer</item>
                             <item>
                                <emph render="italic">Sweet Charity</emph> Palace opening</item>
                             <item>Tomorrow Show</item>
                             <item>Gwen Verdon Interview</item>
                             <item>Terry Wogan Show (BBC)</item>
                          </list>
                       </item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">WNET/13 Research: Photos</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) Assorted photographs printed for WNET use: Bob Fosse and Gwen
              Verdon professional/personal miscellaneous, primarily black and white,
              8x10, including stills from <emph render="italic">How To Succeed In
                 Business</emph>, <emph render="italic">New Girl In Town</emph>, <emph render="italic">Bells Are Ringing</emph>, <emph render="italic">Redhead</emph>, <emph render="italic">Pal Joey</emph>, <emph render="italic">All That Jazz</emph>, and photos of Fosse, Joan
              McCracken, et al.</item>
                    </list>
                 </item>
              </list>
           </item>
           <item>
              <emph render="underline">
                 <emph render="bold">Film</emph>
              </emph>
              <list listtype="unordered" mark="circle">
                 <item>
                    <emph render="bold">General</emph>
                    <list listtype="unordered" mark="circle">
                       <item>[Note: All materials are located in the Motion Picture, Broadcasting,
              and Recorded Sound Division (MBRS) of the Library of Congress. As
              available, LC record numbers are indicated next to each film, video, or
              sound recording. Includes film picture and soundtrack elements.
              Identifications on film elements have been taken from leaders and cans;
              these materials are not cross referenced with individual
              productions.]</item>
                       <item>Fosse Memorial, Stanley Donen [can, 16mm]</item>
                       <item>Fosse Memorial, 2 of 3 [35mm film case]</item>
                       <item>Fosse Memorial, 3 of 3 [35mm film case]</item>
                       <item>
                          <emph render="italic">Cabaret</emph> [16mm film case]</item>
                       <item>
                          <emph render="italic">Lenny</emph> [16mm film case]</item>
                       <item>Person To Person, Gwen Verdon [can, 16mm]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">The Little Prince</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) <emph render="italic">The Little Prince</emph>: Snake Dance, Scene
              160, Dupe Mag Soundtrack, 592 ft., 35mm</item>
                       <item>2) <emph render="italic">The Little Prince</emph>: Snake Dance, black
              and white dupe action for the above track, 35mm</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">Unidentified</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) Marked Universal, Prod. # 53124, B Neg, 8/30/79, Reel 1</item>
                       <item>2) Marked Universal, Prod. # 50917, B Neg, 11/16/78</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">Television Commercials, Various</emph>
                    <list listtype="unordered" mark="circle">
                       <item>16mm film clips for commercials:<list listtype="unordered" mark="circle">
                             <item>1) <emph render="italic">Chicago</emph> #3, Billy's Girls</item>
                             <item>2) <emph render="italic">Pippin</emph>, 1 1/2 min version</item>
                             <item>3) <emph render="italic">Chicago</emph> #2, Gwen Verdon and
                    Chita Rivera</item>
                             <item>4) <emph render="italic">Chicago</emph>, Jazz :30</item>
                             <item>5) Fosse, American Express</item>
                             <item>6) <emph render="italic">Pippin</emph> II</item>
                             <item>7) <emph render="italic">Pippin</emph>, Dance, color :60</item>
                             <item>8) 8mm film from Peter Turgeon (?)</item>
                             <item>9) 16mm color film on reel - Ben Vereen at head, <emph render="italic">Pippin</emph>?</item>
                          </list>
                       </item>
                       <item>Additional Audio Tapes<list listtype="unordered" mark="circle">
                             <item>1) Audio tape: Everything Old Is New Again</item>
                             <item>2) Audio tape: Peter Allen songs</item>
                          </list>
                       </item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">Star 80</emph>
                    <list listtype="unordered" mark="circle">
                       <item>35mm prints, in carrying cases:<list listtype="unordered" mark="circle">
                             <item>1) <emph render="italic">Star 80</emph>, Reels 4, 5, 6, marked
                    "Back Up #1, 8/26/83"</item>
                             <item>2) <emph render="italic">Star 80</emph>, Reels 4, 5, 6, marked
                    "interneg check print, 8/8/83"</item>
                             <item>3) <emph render="italic">Star 80</emph>, Reels 1, 2, 3, marked "
                    #2 Preferred Print, 8/16/83"</item>
                             <item>4) <emph render="italic">Star 80</emph>, Reel 6, marked "Back Up
                    print" [single reel case]</item>
                             <item>5) <emph render="italic">Star 80</emph>, Reels 1, 2, 3, marked
                    "#1 Back Print, 8/26/83"</item>
                             <item>6) <emph render="italic">Star 80</emph>, Reels 1, 2, 3,, marked
                    "NY Back Up Print"[film needs cleaning; one badly rusted
                    reel]</item>
                             <item>7) <emph render="italic">Star 80</emph>, Reels 4, 5 marked "Back
                    Up Only, do not screen"</item>
                             <item>8) <emph render="italic">Star 80</emph>, Reels 1, 2, 3, marked
                    "interneg check print, 8/8/83"</item>
                             <item>9) <emph render="italic">Star 80</emph>, Reels 4, 5, 6, marked
                    "NY Back Up Print</item>
                          </list>
                       </item>
                       <item>Reel 6, "Wet gate reel" [in box, 35mm]</item>
                       <item>Reel 6, "non-splice" [can, 35mm]</item>
                       <item>Reel 6, "splice" [can, 35mm]</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">Star 80 Film Elements</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) Scene 76, Carnival, Paul and Eileen, A Cam, B Negative, PIX</item>
                       <item>2) Wild Track</item>
                       <item>3) Scene 76, Wild Tack, Eileen's dialogue</item>
                       <item>4) Scene 77, August Playmate, Hugh Hefner, Dorothy Stratten, picture
              track</item>
                       <item>5) Scene 76, Look at Me, B cam, B negative</item>
                       <item>6) Scene 76, Look at Me, B cam, B negative</item>
                       <item>Reel 6, FXB (35mm picture track)</item>
                       <item>Reel 6, DIAL X (35mm picture and soundtrack)</item>
                       <item>Reel 6, FX D [35mm picture track]</item>
                       <item>Reel 6, FX A [35mm picture track]</item>
                       <item>Reel 6, DUB DIA C [35mm picture and soundtrack]</item>
                       <item>Reel 6, FXC R-6</item>
                       <item>Reel 6, FXH R-6</item>
                       <item>Reel 6, FXI R-6</item>
                       <item>Reel 4, Music 6</item>
                       <item>Reel 6, Dub Dia A</item>
                       <item>Reel 6, Dia D</item>
                       <item>Reel 6, Dia B</item>
                       <item>Reel 6, Dia C</item>
                       <item>Reel 6, Pix</item>
                       <item>Reel 6, Pix (sic)</item>
                       <item>Reel 6, Dia A</item>
                       <item>Reel 6, Dub Dia B</item>
                       <item>Reel 6, FXE R-6</item>
                       <item>Reel 6, FXF, R-6</item>
                       <item>Reel 9?, Backup Pix</item>
                       <item>Reel 5, Music, 2B</item>
                       <item>Reel 5, Music, 2A</item>
                       <item>Reel 5, Music 1</item>
                       <item>Reel 5, Music 4</item>
                       <item>Reel 5, Music 3</item>
                       <item>Reel 5, Music 5</item>
                       <item>Reel 5, Music 6</item>
                       <item>Reel 5, Music 7</item>
                       <item>Unidentified</item>
                       <item>Reel 6, FXG</item>
                       <item>Reel 5, C trk, magnetic stripe</item>
                       <item>Reel 5, D trk, magnetic stripe</item>
                       <item>Reel 5, A trk, magnetic stripe</item>
                       <item>Reel 5, B trk, magnetic stripe (music)</item>
                       <item>R3AB ?</item>
                       <item>Reel 5, MX Dupe Pic 2/25/83</item>
                       <item>Reel 5, FXF</item>
                       <item>Reel 5, FXC</item>
                       <item>Reel 5, FXE</item>
                       <item>Reel 5, FXH</item>
                       <item>Reel 5, FXG</item>
                       <item>Reel 5, FXB</item>
                       <item>Reel 5, FXA</item>
                       <item>Reel 5, FXD</item>
                       <item>Reel 5, Dia A</item>
                       <item>Reel 5, Dia C</item>
                       <item>Reel 5, Dub Dia A</item>
                       <item>Reel 5, Dia Y</item>
                       <item>Reel 5, Dia X</item>
                       <item>Reel 5, Dia B</item>
                       <item>Reel 5, Dub Dia B</item>
                       <item>Reel 5, Dub Dia C</item>
                    </list>
                 </item>
                 <item>
                    <emph render="bold">Star 80 Music</emph>
                    <list listtype="unordered" mark="circle">
                       <item>1) Playback, Sookie Sookie</item>
                       <item>2) Playback, We've Only Just Begun</item>
                       <item>3) Playback, One Way Or Another</item>
                       <item>4) Wild Track: Black Eyed Blues [Joe Cocker]</item>
                       <item>5) Playback, Do I Do</item>
                       <item>6) Playback, Adagio In G [Albinoni]</item>
                       <item>1) Playback: YMCA</item>
                       <item>2) Playback: Love's Theme</item>
                       <item>3) Playback: Tubular Bells</item>
                       <item>4) Playback: Bartok Concerto For Orchestra</item>
                       <item>5) Playback: Lay Down Sally [mansion, Scene 90]</item>
                       <item>6) Playback: Up On Cripple Creek [mansion, Scene 90]</item>
                    </list>
                 </item>
              </list>
           </item>
           <item>
              <emph render="underline">
                 <emph render="bold">Miscellaneous</emph>
              </emph>
              <list listtype="unordered" mark="circle">
                 <item>1. Two Time Charlie [can, 8mm]</item>
                 <item>2. Take All Of Me, Count Basie [Audio tape, in can]</item>
                 <item>3. 16mm soundtrack labeled "Synch, Jump cut"</item>
                 <item>4. 16mm color film (release print) segment, labeled "sound fill," but is
        part of a Montgomery Clift film</item>
                 <item>5. 16mm black and white film clips, labeled "trims," unidentified</item>
                 <item>6. 16mm black and white film clips, labeled "outtakes" unidentified</item>
                 <item>7. Unidentified audio tape, no label</item>
                 <item>8. Miscellaneous can containing audio tape: "Traffic, Children Playing, Baby
        Crying," few feet of <emph render="italic">Star 80</emph> titles few feet of
           <emph render="italic">Star 80</emph> slides, audio tape labeled "Waters?
        trims")</item>
                 <item>9. Small can, 16mm black and white film, labeled "Trims, Jumpcut"</item>
                 <item>10. <emph render="italic">The Little Prince</emph> - 35mm audio and picture
        for Bob Fosse dance sequence</item>
              </list>
           </item>
        </list>
     </odd>
        EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].subnotes.size).to eq 1
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_unorderedlist"
      expect(resource.notes[0].subnotes[0].title).to eq "Audiovisual Materials"
      expect(resource.notes[0].subnotes[0].items.size).to eq 5
      item_5 = Nokogiri::XML::DocumentFragment.parse(resource.notes[0].subnotes[0].items[4])
      expect(item_5.xpath('descendant::item').size).to eq 10
    end
  end

  it "can ingest defined lists" do
    xml = <<~EAD
    <bioghist>
        <p>
           <emph render="bold">Related Publications:</emph>
        </p>
        <list listtype="deflist">
           <defitem>
              <label>Chandler, James Winston</label>
              <item>
                 <emph render="italic">The Function of the Choreographer in the Development of the
        Conceptual Musical: An Examination of the Work of Jerome Robbins, Bob Fosse,
        and Michael Bennett on Broadway Between 1944 and 1981.</emph> Ann Arbor, MI:
     UMI Dissertation Services, 1993.</item>
           </defitem>
           <defitem>
              <label>Gargaro, Kenneth Vance</label>
              <item>
                 <emph render="italic">The Work of Bob Fosse and the Choreographer-directors in the
        Translation of Musicals to the Screen</emph>. Ann Arbor, MI: University
     Microfilms International, 1980.</item>
           </defitem>
         </list>
       </bioghist>
      EAD
    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].subnotes.size).to eq 2
      expect(resource.notes[0].subnotes[1].jsonmodel_type).to eq "note_definedlist"
    end
  end

  # AS-377
  it "imports nested bioghist head tags correctly" do
    with_top_level_head = <<~EAD
            <bioghist encodinganalog="545" id="mferd313e252v">
               <head>Biographical Sketches</head>
               <bioghist id="mferd313e255v">
                  <head>Alice Eversman</head>
                  <p>Alice Eversman was born on September 4, 1885, in Effingham, Illinois, to John Caspar...</p>
               </bioghist>
               <bioghist id="mferd313e290v">
                  <head>Elena de Sayn</head>
                  <p>Elena de Sayn (also known as Helena, Helen, or Yelena) was born on May 10...</p>
               </bioghist>
             </bioghist>
            EAD

    with_converter_instance(with_top_level_head) do |converter, batch|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].label).to eq "Biographical Sketches"
      expect(resource.notes[0].subnotes.size).to eq 2
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[0].content).to start_with "<head>Alice Eversman</head>\n\nAlice Eversman was born"
      expect(resource.notes[0].subnotes[1].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[1].content).to start_with "<head>Elena de Sayn</head>\n\nElena de Sayn (also known"
    end

    without_top_level_head = <<~EAD
            <bioghist encodinganalog="545" id="mferd313e252v">
               <bioghist id="mferd313e255v">
                  <head>Alice Eversman</head>
                  <p>Alice Eversman was born on September 4, 1885, in Effingham, Illinois, to John Caspar...</p>
               </bioghist>
               <bioghist id="mferd313e290v">
                  <head>Elena de Sayn</head>
                  <p>Elena de Sayn (also known as Helena, Helen, or Yelena) was born on May 10...</p>
               </bioghist>
             </bioghist>
            EAD

    with_converter_instance(without_top_level_head) do |converter, batch|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].label).to be_nil
      expect(resource.notes[0].subnotes.size).to eq 2
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[0].content).to start_with "<head>Alice Eversman</head>\n\nAlice Eversman was born"
      expect(resource.notes[0].subnotes[1].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[1].content).to start_with "<head>Elena de Sayn</head>\n\nElena de Sayn (also known"
    end
  end

  # AS-425
  it "can import odd notes with &amp entities" do
    odd_with_table = <<~EAD
          <odd>
              <head althead="Research &amp; Scholarly Orgs">Research and Scholarly Organizations </head>
              <table>
                  <tgroup cols="2">
                      <colspec colwidth="50*"/>
                      <colspec colwidth="50*"/>
                      <thead>
                          <row>
                              <entry>Name</entry>
                              <entry>LCCN</entry>
                          </row>
                      </thead>
                      <tbody>
                          <row>
                              <entry>American Council of Learned Societies records, 1910-2011</entry>
                              <entry>
                                  <ref href="https://lccn.loc.gov/mm80054288">
                                      https://lccn.loc.gov/mm80054288</ref>
                              </entry>
                          </row>
                      </tbody>
                  </tgroup>
              </table>
            </odd>
            EAD

    with_converter_instance(odd_with_table) do |converter, batch|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].label).to eq "Research and Scholarly Organizations"
      expect(resource.notes[0].subnotes.size).to eq 1
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[0].content).to start_with "<table>"
    end
  end

  # AS-426
  it "can import defined lists with listhead elements" do
    deflist = <<~EAD
          <relatedmaterial encodinganalog="544 1" id="mferd81e228v">
             <head> Related Archival Collections at the Library of Congress </head>
             <list listtype="deflist">
                <listhead>
                   <head01 id="nbcarch"> The NBC Archives at the Library of Congress include the NBC
          Press Releases (the subject of this finding aid) as well as the following archival
          NBC collections. </head01>
                </listhead>
                <defitem>
                   <label>NBC History Files </label>
                   <item> The National Broadcasting Company History files include memoranda,
          correspondence, speeches, reports, policy statements, and pamphlets covering the
          creation of the network, its growth in the field of radio, and its subsequent
          expansion into television broadcasting. </item>
                </defitem>
                <defitem>
                   <label>Radio Log Books. Manuscript </label>
                   <item> The Library holds log books for WEAF and WNBC (1922 - 1955), for WJZ (1923 -
          1941), and for WJY (1923 - 1926.) </item>
                </defitem>
             </list>
          </relatedmaterial>
            EAD

    with_converter_instance(deflist) do |converter, batch|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].label).to eq "Related Archival Collections at the Library of Congress"
      expect(resource.notes[0].subnotes.size).to eq 1
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_definedlist"
      expect(resource.notes[0].subnotes[0].title).to eq "The NBC Archives at the Library of Congress include the NBC Press Releases (the subject of this finding aid) as well as the following archival NBC collections."
    end
  end

  # AS-425
  it "can import notes with blockquote elements" do
    deflist = <<~EAD
               <odd>
                  <blockquote>
                     <p> “From General Marshall’s 3rd Report prepared from hemisphere drawing in
            Atlas for U.S. Citizen. B&amp;W-colored for this report. 1945.” </p>
                  </blockquote>
                  <blockquote>
                     <p>
                        <emph>Fortune</emph> map for General Marshall’s Third Report October 1945.
            This view is that from a great circle route from the United States to
            Europe.” </p>
                  </blockquote>
               </odd>
            EAD

    with_converter_instance(deflist) do |converter, batch|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes.size).to eq 1
      expect(resource.notes[0].subnotes.size).to eq 1
      expect(resource.notes[0].subnotes[0].jsonmodel_type).to eq "note_text"
      expect(resource.notes[0].subnotes[0].content).to eq "<blockquote>\n\n“From General Marshall’s 3rd Report prepared from hemisphere drawing in Atlas for U.S. Citizen. B&amp;W-colored for this report. 1945.”\n\n</blockquote>\n<blockquote>\n\n<emph>Fortune</emph> map for General Marshall’s Third Report October 1945. This view is that from a great circle route from the United States to Europe.”\n\n</blockquote>"
    end
  end

  # AS-441
  it "converts paragraphs into double line breaks" do
    xml = <<~EAD
           <odd>
             <head id="artists">label</head>
             <p>
             foo
             </p>
             <p>
             bar
             </p>
           </odd>
           EAD

    with_converter_instance(xml) do |converter, batch, records_in_working_file|
      resource = ASpaceImport::JSONModel(:resource).new(build(:json_resource).to_hash)
      batch << resource
      converter.run
      batch.flush
      expect(resource.notes[0].label).to eq "label"
      expect(resource.notes[0].subnotes[0]["content"]).to eq "foo\n\nbar"
    end
  end

end
