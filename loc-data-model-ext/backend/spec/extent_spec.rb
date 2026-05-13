require 'spec_helper'

describe 'Extent Subrecord Extensions' do

  it "adds extent.physical_description" do
    extent = Extent.create_from_json(
      JSONModel(:extent).
        from_hash({
                    portion: "whole",
                    number: "1",
                    extent_type: "gigabytes",
                    physical_description: "a gig"
                  })
    )
    id = extent[:id]
    expect(Extent[id].physical_description).to eq("a gig")
  end
end
