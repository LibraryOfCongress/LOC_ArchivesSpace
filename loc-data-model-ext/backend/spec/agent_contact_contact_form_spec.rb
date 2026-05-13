require 'spec_helper'

describe 'contact form field' do

  it "allows repositories to have a contact form field" do

    opts = { contact_form: "https://example.com/contact" }

    c1 = build(:json_agent_contact, opts)

    agent = AgentPerson.create_from_json(build(:json_agent_person, :agent_contacts => [c1]))
    expect(AgentPerson[agent[:id]].agent_contact[0][:contact_form]).to eq("https://example.com/contact")
  end

  it "rejects non url values" do

    opts = { contact_form: "not a url" }

    c1 = build(:json_agent_contact, opts)

    expect {
      agent = AgentPerson.create_from_json(build(:json_agent_person, :agent_contacts => [c1]))
    }.to raise_error
  end
end
