require 'spec_helper'
require_relative '../model/finding_aid_pdf'

describe 'PDF Record Model' do

  let(:resource) {
    create(:json_resource,
           publish: true,
           ead_location: "https://handle.net/1234",
           notes: [
             build(:json_note_multipart,
                   type: "otherfindaid",
                   subnotes: [
                     build(:json_note_text,
                           publish: true,
                           content: "The Abbe Papers are described in the <title localtype=\"simple\"> <part>Library of Congress Information Bulletin,</part> </title> vol. 22, no. 29 (22 July 1963), pages 357-358, and in Nathan Reingold, \"A Good Place to Study Astronomy,\" <title localtype=\"simple\"> <part>Library of Congress Quarterly Journal of Current Acquisitions,</part> </title> vol. 20, no. 4 (September 1963), pages 211-217."
                          )]),
             build(:json_note_multipart,
                   type: "arrangement",
                   subnotes: [
                     build(:json_note_text,
                           publish: true,
                           content: "This collection is arranged in eight series:"
                          ),
                     JSONModel(:note_unorderedlist).from_hash(
                       {
                         "items" => [
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"diar\">Diaries, 1862-1889</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"genl\">General Correspondence, 1850-1916</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"fam\">Family Correspondence and Related Papers, 1858-1954</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"subj\">Subject File, 1855-1884</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"spe\">Speech and Article File, 1850-1912</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"prin\">Printed Matter, 1859-1911</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"ref_id10001\">2023 Addition, 1887-1936</ref>",
                           "<ref actuate=\"onrequest\" show=\"replace\" target=\"ov\">Oversize, 1870</ref>"
                         ],
                         "publish" => true
                       })
                   ]),
             build(:json_note_multipart,
                   type: "scopecontent",
                   subnotes: [
                     build(:json_note_text,
                           publish: true,
                           content: "see also <ref actuate=\"onrequest\" show=\"replace\" target=\"lot13111\">13111</ref>"
                          )
                   ]),
             build(:json_note_multipart,
                   type: "bioghist",
                   subnotes: [
                     build(:json_note_chronology,
                           publish: true,
                           items: [
                             {
                               "place": " <part>Mine Run</part> \n <part>Gettysburg</part> \n <part> Wilderness</part> \n <part>Spotsylvania</part> \n <part>Petersburg</part> \n <part>Weldon Railroad</part> ",
                               "events": [
                                 "Participated in many battles of the Civil War including <geogname> <part>Mine Run</part> </geogname>, <geogname> <part>Gettysburg</part> </geogname>, <geogname> <part> Wilderness</part> </geogname>, <geogname> <part>Spotsylvania</part> </geogname>, <geogname> <part>Petersburg</part> </geogname>, and <geogname> <part>Weldon Railroad</part> </geogname>"
                               ],
                               "date_from": "1862",
                               "date_to": "1865"
                             }
                           ])
                   ])
           ])
  }

  let(:resource_with_unpublished) {
    resource = create(:json_resource,
                      publish: true,
                      notes: [
                        build(:json_note_multipart,
                              type: "otherfindaid",
                              publish: false,
                              subnotes: [
                                build(:json_note_text,
                                      content: "shhhh"
                                     )]),
                        build(:json_note_multipart,
                              type: "otherfindaid",
                              subnotes: [
                                build(:json_note_text,
                                      publish: true,
                                      content: "!!!!"
                                     ),
                                build(:json_note_text,
                                      publish: false,
                                      content: "shhhh"
                                     )
                              ])
                      ])
    create(:json_archival_object,
           resource: {ref: resource.uri},
           publish: true,
           title: "Published")

    create(:json_archival_object,
           resource: {ref: resource.uri},
           publish: false,
           title: "Unpublished")

    resource
  }



  it "exposes the handle for the resource" do

    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    expect(record.ead_location).to eq resource.ead_location
  end

  it "exposes the level for the an archival object" do
    ao = create(:json_archival_object,
                resource: {ref: resource.uri},
                publish: true,
                level: "series")


    pdf = FindingAidPDF.new($repo_id, resource.id)
    pdf.each_ao do |record, depth, is_parent|
      expect(record.level).to eq("series")
    end
  end

  it "filters <part> tags from otherfindaid notes and doesn't escape inline quotes" do
    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    expect(record.notes['otherfindaid'][0]['note_text']).to eq "The Abbe Papers are described in the <span class=\"title\" localtype=\"simple\"> <span class=\"part\">Library of Congress Information Bulletin,</span> </span> vol. 22, no. 29 (22 July 1963), pages 357-358, and in Nathan Reingold, \"A Good Place to Study Astronomy,\" <span class=\"title\" localtype=\"simple\"> <span class=\"part\">Library of Congress Quarterly Journal of Current Acquisitions,</span> </span> vol. 20, no. 4 (September 1963), pages 211-217."
  end

  it "formats unordered lists correctly" do
    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    arrangement_note = record.notes['arrangement']
    # todo
  end

  it "handles anchor tags correctly" do
    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    scope_note = record.notes['scopecontent']
    expect(scope_note[0]['note_text']).to eq "see also <a href=\"#lot13111\">13111</a>"
  end

  it "replaces line breaks with br tags in chronitem place field" do
    pdf = FindingAidPDF.new($repo_id, resource.id)
    record = pdf.instance_variable_get(:@resource)
    biog_note = record.notes['bioghist']
    puts biog_note[0]['note_text']
    doc = Nokogiri::HTML::DocumentFragment.parse(biog_note[0]['note_text'])
    non_empty_children = doc.xpath("//th")[0].children.reject { |c| c.text.strip.empty? && c.name != "br" }
    expect(non_empty_children[2].text).to eq "Mine Run"
    expect(non_empty_children[3].name).to eq "br"
    expect(non_empty_children[4].text).to eq "Gettysburg"
  end

  it "supports an include_unpublished option" do
    pdf = FindingAidPDF.new($repo_id, resource_with_unpublished.id, include_unpublished: false)
    record = pdf.instance_variable_get(:@resource)
    ordered_records = pdf.instance_variable_get(:@ordered_records)
    expect(ordered_records.entries.length).to eq 2
    expect(record.notes.values.flatten.length).to eq 1
    expect(record.notes.values.flatten.map {|n| n['subnotes'] }.length).to eq 1
    pdf = FindingAidPDF.new($repo_id, resource_with_unpublished.id, include_unpublished: true)
    record = pdf.instance_variable_get(:@resource)
    ordered_records = pdf.instance_variable_get(:@ordered_records)
    expect(ordered_records.entries.length).to eq 3
    expect(record.notes.values.flatten.length).to eq 2
    expect(record.notes.values.flatten.map {|n| n['subnotes'] }.flatten.length).to eq 3
  end

end
