require 'spec_helper'
require_relative '../../loc_mixed_content_parser'

describe 'Mixed Content Parsing of Note Content' do

  it 'parses <list> content into an HTML list' do
    list_xml = <<~LIST
      <list listtype="unordered" mark="circle">
         <item>
            <ref show="replace" actuate="onrequest" target="s1229l00000">Series I. Class L,
               1912-1929</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="s2945l00000">Series II. Class L,
               1929-1945</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="s4650l00000">Series III. Class L,
               1946-1950</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="ead100001">Series IV. Class LP,
               1950-1977</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="ead101227">Series V. Class LF,
               1966-1977</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="ead101239">Series VI. Class LFO,
               1965-1977</ref>
         </item>
         <item>
            <ref show="replace" actuate="onrequest" target="ead101249">Series VII. Class LU,
               1950-1977</ref>
         </item>
      </list>
      LIST

    parsed_content = LocMixedContentParser::parse(list_xml, '/foo', :wrap_blocks => false)
    doc = Nokogiri::XML::DocumentFragment.parse(parsed_content)
    expect(doc.children[0].name).to eq "ul"
    expect(doc.children[0].children.select {|c| c.name == "li"}.size).to eq 7
  end

  it 'replaces <part> tags with <span>' do
    xml = <<~XML
      <title render="doublequote">
         <part>Cape Breton Fiddle and Piano Music: The Beaton Family</part>
      </title>
      XML
    parsed_content = LocMixedContentParser::parse(xml, '/foo', :wrap_blocks => false)
    doc = Nokogiri::XML::DocumentFragment.parse(parsed_content)
    expect(doc.children[0].name).to eq "span"
    expect(doc.children[0].children[1].name).to eq "span"
    expect(doc.children[0].children[1].text).to eq "Cape Breton Fiddle and Piano Music: The Beaton Family"
  end
end
