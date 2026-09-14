require 'spec_helper'

describe 'Note Rendering' do

  it "removes part tags from chronlist items" do

    now = Time.now.to_i
    repository = create(:repo, :repo_code => "notes_#{now}", publish: true)
    set_repo repository

    resource = create(:json_resource,
                      publish: true,
                      ead_location: "https://handle.net/1234",
                      notes: [
                        build(:json_note_multipart,
                              type: "bioghist",
                              subnotes: [
                                build(:json_note_chronology,
                                      publish: true,
                                      items: [
                                        {
                                          "place": " <part>St. Louis, Mo.</part> ",
                                          "events": [
                                            "Born, <geogname> <part>St. Louis, Mo.</part> </geogname>"
                                          ],
                                          "date_singular": "1907, June 17"
                                        }
                                      ])
                              ])])

    run_indexers
    client = ArchivesSpaceClient.instance
    @resource = client.get_record("/repositories/#{repository.id}/resources/#{resource.id}",
                                  { 'resolve[]' => ['repository:id'] })
    stripped = @resource.notes['bioghist'][0]['note_text'].gsub("\n", "").gsub(/>\s+</, "><")
    expect(stripped).to eq "<dl><dt>1907, June 17</dt><dt><span class=\"part\">St. Louis, Mo.</span></dt><dd>Born, <span class=\"geogname\"><span class=\"part\">St. Louis, Mo.</span></span></dd></dl>"
  end
end
