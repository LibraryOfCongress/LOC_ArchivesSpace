require 'spec_helper'

describe 'Revision Statement Subrecord Extensions' do


  it "allows revision statements to have type, agent_type, and agent fields" do

    revision_statement = RevisionStatement.create_from_json(
      JSONModel(:revision_statement).
        from_hash({
                    date: "2025",
                    description: "something",
                    type: "created",
                    agent_type: "machine",
                    agent: "ChatGPT"
                  })
    )
    id = revision_statement[:id]
    expect(RevisionStatement[id].type).to eq("created")
  end
end
