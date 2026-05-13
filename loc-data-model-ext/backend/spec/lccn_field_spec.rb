require 'spec_helper'

describe 'LCCN field' do

  let(:lccn) { "E123.B100" }

  it "allows resources to have an lccn field" do
    opts = {:lccn => lccn}

    resource = create_resource(opts)
    expect(Resource[resource[:id]].lccn).to eq(lccn)
  end

  it "allows accessions to have an lccn field" do
    opts = {:lccn => lccn}

    accession = create_accession(opts)

    expect(Accession[accession[:id]].lccn).to eq(lccn)
  end

end
