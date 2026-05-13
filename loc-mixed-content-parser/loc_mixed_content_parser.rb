require 'java'

module LocMixedContentParser

  def self.parse(content, base_uri, opts = {} )
    opts[:pretty_print] ||= false

    return if content.nil?

    content.strip!
    content.chomp!

    return '' if content.empty?

    # archon does things differently.....
    content.gsub!("\n\t", "\n\n")

    # transform blocks of text seperated by line breaks into <p> wrapped blocks
    content = content.split("\n\n").inject("") { |c, n| c << "<p>#{n}</p>" } if opts[:wrap_blocks]

    document = org.jsoup.Jsoup.parse(content, base_uri, org.jsoup.parser.Parser.xmlParser())
    document.outputSettings.prettyPrint(opts[:pretty_print])

    table_row = document.select("row")
    table_row.tagName("tr")
    table_cell = document.select("entry")
    table_cell.tagName("td")

    list = document.select("list")
    list.tagName("ul")
    list_item = list.select("item")
    list_item.tagName("li")

    document.outputSettings.escapeMode(Java::OrgJsoupNodes::Entities::EscapeMode.xhtml)
    document.outputSettings.prettyPrint(opts[:pretty_print])

    # replace lb with br
    document.select("lb").tagName("br")

    # tweak the emph tags
    [ "part", "emph", "title", "unitdate" ].each do |tag|
      document.select(tag).each do |emph|
        # make all emph's a span
        emph.tagName("span")

        # <emph> should render as <em> if there is no @render attribute. If there is, render as follows:
        if emph.attr("render").empty?
          emph.attr("class", "emph render-none")

        # render="nonproport": <code>
        elsif emph.attr("render") === "nonproport"
          emph.attr("class", "emph render-#{emph.attr("render")}")
          emph.tagName("code")
          emph.removeAttr("render")

        # set a class so CSS can style based on the render value
        else
          emph.attr("class", "emph render-#{emph.attr("render")}")
          emph.removeAttr("render")
        end
      end
    end

    # translate EAD table to HTML
    table_row = document.select("row")
    table_row.tagName("tr")
    table_cell = document.select("entry")
    table_cell.tagName("td")
    output = document.toString()
    output
  end

  def self.remove_tags(xml_document)
    text = ""
    if xml_document.is_a? String
      xml_document = Nokogiri::XML.parse(xml_document)
    end
    xml_document.children.each do |child|
      if child.node_name == "text"
        text += child.text
      else
        text += self.remove_tags(child)
      end
    end
    text
  end
end
