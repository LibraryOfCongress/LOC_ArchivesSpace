require 'export_spec_helper'

describe "EAD3 Export" do

  def build_linked_agents()
    agent = create(:json_agent_person)

    linked_agent = {
      ref: agent.uri,
      role: 'creator',
      :terms => [build(:json_term), build(:json_term)]
    }
    [linked_agent]
  end

  def build_notes
    notes = [
      build(:json_note_multipart,
            type: "odd",
            subnotes: [
              build(:json_note_orderedlist),
              build(:json_note_definedlist),
              build(:json_note_text)
            ]
           )
    ]
    notes
  end

  def load_export_fixtures

    resource = create(:json_resource, :linked_agents => build_linked_agents,
                      :notes => build_notes,
                      # :instances => instances,
                      :finding_aid_status => "completed",
                      :finding_aid_author => 'Rubenstein Staff + Landskröner',
                      :finding_aid_filing_title => "this is a filing title",
                      :finding_aid_series_statement => "here is the series statement",
                      :publish => true,
                      :metadata_rights_declarations => [
                        build(:json_metadata_rights_declaration),
                        build(:json_metadata_rights_declaration, :file_uri => nil)
                      ])

    @resource = JSONModel(:resource).find(resource.id, 'resolve[]' => 'top_container')
  end


  before(:all) do

    as_test_user('admin') do
      RSpec::Mocks.with_temporary_scope do
        # EAD export normally tries the search index first, but for the tests we'll
        # skip that since Solr isn't running.
        allow(Search).to receive(:records_for_uris) do |*|
          {'results' => []}
        end

        as_test_user("admin", true) do
          load_export_fixtures
          @doc = get_xml("/repositories/#{$repo_id}/resource_descriptions/#{@resource.id}.xml?include_unpublished=true&include_daos=true&include_uris=true&ead3=true")
          raise Sequel::Rollback
        end
      end
    end
  end

  it "uses a custom value for 'odd' note type head tags" do
    expect(@doc.xpath("//xmlns:odd/xmlns:head").text).to eq "Other Descriptive Data"
  end

end
