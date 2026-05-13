require 'spec_helper'
require '/Users/bhoffman/D/archivesspace/common/lib/jsoup-1.8.1.jar'

describe ObjectsController, type: :controller do
  before(:all) do
    @repo = create(:repo, repo_code: "objects_controller_test_#{Time.now.to_i}",
                          publish: true)
    set_repo @repo
    run_indexers
  end

  describe 'Archival Objects' do
    render_views

    before(:all) do
      @resource = create(:resource, publish: true, title: 'Resource with child')


      @arch_obj = create(:archival_object,
        title: "<title render=\"doublequote\"><part>Cape Breton Fiddle and Piano Music: The Beaton Family</part></title>",
        publish: true,
        resource: {'ref' => @resource.uri},
      )
      run_indexers
    end

    describe 'mixed content in breadcrumb' do
      it 'maps title and part tags to span tags' do
        get(:show, params: {rid: @repo.id, obj_type: 'archival_objects', id: @arch_obj.id})

        page = Capybara.string(response.body)

        page.find(:css, 'ul.breadcrumb q.title span.part') do |fc|
          expect(fc.text).to eq("Cape Breton Fiddle and Piano Music: The Beaton Family")
        end
      end
    end

  end

end
