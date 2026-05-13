require 'spec_helper'

describe 'Instance Type' do

  it "is optional" do
    top = create(:json_top_container)
    opts = {:instances => [build(:json_instance,
                                 instance_type: nil,
                                 sub_container: build(:json_sub_container,
                                                      top_container: {ref: top.uri}))]}

    resource = create_resource(opts)
    res = Resource[resource[:id]]
    expect(res.instance.length).to eq(1)
    expect(res.instance[0].instance_type).to eq(opts[:instances][0]['instance_type'])

    res = URIResolver.resolve_references(Resource.to_jsonmodel(resource[:id]), ['top_container'])
    expect(res['instances'][0]["sub_container"]['top_container']['_resolved']["type"]).to eq(top["type"])
  end

  it "doesn't bork spreadsheet builder" do
    resource = create(:json_resource)
    top = create(:json_top_container)
    opts = {instances: [build(:json_instance,
                              # instance_type: "audio",
                              instance_type: nil,
                              sub_container: build(:json_sub_container,
                                                   top_container: {ref: top.uri})),
                        build(:json_instance_digital)],
            resource: { ref: resource.uri }}

    ao = create(:json_archival_object, opts)

    builder = SpreadsheetBuilder.new(resource.uri,
                                     [ao.uri],
                                     1,
                                     0,
                                     1,
                                     [
                                       'instance'
                                     ])

    builder.dataset_iterator do |current_row, locked_column_indexes|
      instances = current_row.select {|r| r.column.property_name == "instances" }
      expect(instances[2].value).to eq top.indicator
    end
  end
end
