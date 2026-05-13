require 'spec_helper'

describe 'Additional Restrictions Boolean' do

  it "allows resources to have a second restrictions boolean" do
    opts = {restrictions: true, spatial_restrictions: true}

    resource = create_resource(opts)
    expect(Resource.to_jsonmodel(resource[:id]).spatial_restrictions).to eq(true)
  end
end
