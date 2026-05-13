require 'spec_helper'

describe ResourcesController, type: :controller do
  render_views

  before(:all) do
    @repo = create(:repo, repo_code: "resources_test_#{Time.now.to_i}",
                   publish: true)
    set_repo @repo
    @resource = create(:resource, publish: true,
                       notes: [
                         build(:json_note_multipart,
                               type: "bioghist",
                               label: "Test of <emph render=\"italic\">Formatting</emph> tags",
                               subnotes: [
                                 build(:json_note_text, publish: true, content: "Note text"),
                                 build(:json_note_chronology, publish: true,
                                       title: "<emph>More things</emph>",
                                       items: [{ date_singular: "1900" }]
                                      )
                               ])
                       ])

    run_indexers
  end

  it 'should process sgml tags in chronology note title' do
    get(:show, params: {rid: @repo.id, id: @resource.id})
    page = Capybara.string(response.body)
    page.find(:css, ".bioghist.single_note h2 span.emph.render-italic") do |note_label|
      expect(note_label.text).to eq "Formatting"
    end
    page.find(:css, ".bioghist h3 span.emph.render-none") do |chron_title|
      expect(chron_title.text).to eq "More things"
    end
  end
end
