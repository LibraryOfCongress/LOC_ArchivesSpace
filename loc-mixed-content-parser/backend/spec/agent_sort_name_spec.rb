require 'spec_helper'

describe 'SortNameProcessor' do

  it "strips <part> tags from sort names for agent names" do

    n1 = build(:json_name_corporate_entity,
               primary_name: "<part>Brookings Institution.</part>",
               subordinate_name_1: nil,
               subordinate_name_2: nil,
               qualifier: nil,
               dates: nil,
               location: nil,
               number: nil
              )

    agent = AgentCorporateEntity.create_from_json(build(:json_agent_corporate_entity, :names => [n1]))
    expect(AgentCorporateEntity[agent[:id]].name_corporate_entity.first[:sort_name]).to eq "Brookings Institution."

    n2 = build(:json_name_person,
               primary_name: "<part>Bebring, Tom</part>",
               prefix: nil,
               suffix: nil,
               title: nil,
               number: nil,
               fuller_form: nil,
               dates: nil,
               qualifier: nil,
               rest_of_name: nil
              )
    agent = AgentPerson.create_from_json(build(:json_agent_person, :names => [n2]))
    expect(AgentPerson[agent[:id]].name_person.first[:sort_name]).to eq("Bebring, Tom")

    n3 = build(:json_name_family,
               family_name: "<part>Odom family.</part>",
               prefix: nil,
               dates: nil,
               qualifier: nil,
               location: nil
              )
    agent = AgentFamily.create_from_json(build(:json_agent_family, :names => [n3]))
    expect(AgentFamily[agent[:id]].name_family.first[:sort_name]).to eq("Odom family.")
  end
end
