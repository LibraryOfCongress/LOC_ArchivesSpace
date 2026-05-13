require 'tempfile'
require 'action_view'
require 'tilt'
require 'tilt/erubi'
require_relative '../lib/xml_cleaner'
require_relative '../lib/manipulate_node'
require_relative '../helpers/json_helper'
require_relative 'resource'
require_relative 'resource_ordered_records'
require_relative 'archival_object'

class PDFRenderErrorHeader < StandardError; end
class PDFRenderErrorTitlePage < StandardError; end
class PDFRenderErrorTOC < StandardError; end
class PDFRenderErrorResource < StandardError; end
class PDFRenderErrorArchivalObject < StandardError; end
class PDFRenderErrorFooter < StandardError; end

class FindingAidRenderer

  def initialize(finding_aid)
    @template_dir = File.join(File.dirname(__FILE__), '../templates')
    @scope = finding_aid
  end

  def render(ticker)
    layout = get_template('layout.erb')
    archival_object = get_template('archival_object.erb', "(record:, level:, is_parent:)")
    dolinks = get_template('digital_object_links.erb', "(instances:)")
    result = layout.render(@scope) do
      inner_result = ""
      header = get_template('header.erb')
      ticker.log("rendering header")
      inner_result << header.render(@scope)
      body = get_template('body.erb')
      ticker.log("rendering body")
      inner_result << body.render(@scope) do
        titlepage = get_template('titlepage.erb')
        ticker.log("rendering titlepage")
        body_str = titlepage.render(@scope)
        ticker.log("rendering toc")
        toc = get_template('toc.erb')
        body_str += toc.render(@scope)
        resource = get_template('resource.erb')
        ticker.log("rendering resource")
        body_str += resource.render(@scope) do
          ticker.log("rendering do links for resource")
          do_str = dolinks.render(@scope, instances: @scope.instances)
          do_str
        end
        collection_inventory = get_template('collection_inventory.erb')
        ticker.log("rendering collection inventory")
        body_str += collection_inventory.render(@scope) do
          ao_list = ""
          @scope.each_ao do |record, entry, is_parent|
            # ticker.log("rendering #{record.uri}")
            ao_list += archival_object.render(@scope, record: record, level: entry.depth, is_parent: is_parent) do
              do_str = dolinks.render(@scope, instances: record.instances)
              do_str
            end
          end
          ao_list
        end
        body_str
      end
      inner_result
    end

    result
  end

  private

  def template_path(template)
    File.join(@template_dir, template)
  end

  def get_template(template, fixed_locals = "()")
    Tilt::ErubiTemplate.new(template_path(template), fixed_locals: fixed_locals)
  end
end

class FindingAidPDF
  include ManipulateNode
  include JsonHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TextHelper

  DEPTH_1_LEVELS = ['collection', 'recordgrp', 'series']
  DEPTH_2_LEVELS = ['subgrp', 'subseries', 'subfonds']

  attr_reader :repo_id, :resource_id, :archivesspace, :base_url, :repo_code

  def initialize(repo_id, resource_id, base_url=AppConfig[:public_proxy_url])
    @repo_id = repo_id
    @resource_id = resource_id

    @base_url = base_url

    resource = Resource.get_or_die(resource_id)
    # adapted from the PUI Resource model
    # to facilitate copy pasta from pui PDF pipeline
    @resource = PDF::Resource.new({ "json" => URIResolver.resolve_references(
                               Resource.to_jsonmodel(resource),
                               ['repository', 'repository::agent_representation', 'subjects', 'top_container', 'linked_agents', 'digital_object'])
                                  })
    @ordered_records = PDF::ResourceOrderedRecords.new({ "json" => { 'uris' => resource.ordered_records }})
    # make sure finding aid title isn't only like /^\n$/
    if @resource.finding_aid['title'] and @resource.finding_aid['title'] =~ /\w/
      @short_title = @resource.finding_aid['title'].lstrip.split("\n")[0].strip
    end
  end

  def suggested_filename
    # Use the EAD ID.  If that's missing, use the 4-part identifier
    filename = (@resource.ead_id || @resource.four_part_identifier.reject(&:blank?).join('_'))

    # no spaces, please.
    filename.gsub(' ', '_') + '.pdf'
  end

  def short_title
    @short_title || suggested_filename
  end

  # Drop the resource and filter the AOs
  def ordered_aos
    @ordered_records.entries.drop(1).select {|entry|
      if entry.depth == 1
        DEPTH_1_LEVELS.include?(entry.level)
      elsif entry['depth'] == 2
        DEPTH_2_LEVELS.include?(entry.level)
      else
        false
      end
    }
  end

  def instances
    @resource.instances
  end

  def has_children = @ordered_records.entries.length > 1

  def source_file(ticker)
    begin
      # We'll use the original controller so we can find and render the PDF
      # partials, but just for its ERB rendering.
      start_time = Time.now

      @repo_code = @resource.repository_information.fetch('top').fetch('repo_code')
      # .length == 1 would be just the resource itself.


      out_html = Tempfile.new

      # Use a NokogiriPushParser-based
      writer = Nokogiri::XML::SAX::PushParser.new(XMLCleaner.new(out_html))
      record = resource = @resource
      renderer = FindingAidRenderer.new(self)
      rendered = renderer.render(ticker).gsub("&amp;", "___AMPERSAND___").gsub("&", "___AMPERSAND___").gsub("___AMPERSAND___", "&amp;")
      writer.write(rendered)
      out_html.close
      out_html
    rescue => e
      out_html = Tempfile.new

      writer = Nokogiri::XML::SAX::PushParser.new(XMLCleaner.new(out_html))

      location = case e.class.to_s
                 when "PDFRenderErrorHeader"
                   I18n.t('pdf_error.location.location_header')
                 when "PDFRenderErrorTitlePage"
                   I18n.t('pdf_error.location.location_title_page')
                 when "PDFRenderErrorTOC"
                   I18n.t('pdf_error.location.location_toc')
                 when "PDFRenderErrorResource"
                   I18n.t('pdf_error.location.location_resource')
                 when "PDFRenderErrorArchivalObject"
                   I18n.t('pdf_error.location.location_archival_object')
                 when "PDFRenderErrorFooter"
                   I18n.t('pdf_error.location.location_footer')
                 else
                   nil
                 end

      # nil means some other error occured
      if location == nil
        message    = e.message
        orig_class = e.class.to_s
      else
        orig_class, message = e.message.split(';')
      end

      error_html = ""
      error_html += "<body>"
      error_html += "<h1>#{I18n.t('pdf_error.title')}</h1>"
      error_html += "<p>#{I18n.t('pdf_error.description')}</p>"

      unless location == nil
        error_html += "<p><b>#{I18n.t('pdf_error.headings.location')}</b></p>"
        error_html += "<p>#{location}</p>"
      end

      error_html += "<p><b>#{I18n.t('pdf_error.headings.message')}</b></p>"
      error_html += "<p>#{message}</p>"

      error_html += "<p><b>#{I18n.t('pdf_error.headings.type')}</b></p>"
      error_html += "<p>#{orig_class}</p>"

      if orig_class == "Nokogiri::XML::SyntaxError"
        error_html += "<p><b>#{I18n.t('pdf_error.headings.additional_info')}</b></p>"
        error_html += "<p>#{I18n.t('pdf_error.additional_info.invalid_markup')}</p>"
      end

      error_html += "</body>"

      writer.write(error_html)

      out_html.close

      out_html
    end
  end

  def generate(ticker)
    java_import com.lowagie.text.pdf.BaseFont;
    out_html = source_file(ticker)

    pdf_file = Tempfile.new
    pdf_file.close

    renderer = org.xhtmlrenderer.pdf.ITextRenderer.new
    resolver = renderer.getFontResolver

    # ANW-1075: Use Kurinto, followed by Noto Serif by defaults for open source compatibility and Unicode support for Latin, Cyrillic and Greek alphabets
    # Additional fonts can be specified via config file and added via plugin

    font_paths = AppConfig[:pui_pdf_font_files].map do |font|
      File.join(File.dirname(__FILE__),  "../fonts/#{font}")
    end

    font_paths.each do |font_path|
      resolver.addFont(
        font_path,
        "Identity-H",
        true
      );
    end

    renderer.set_document(java.io.File.new(out_html.path))

    # FIXME: We'll need to test this with a reverse proxy in front of it.
    renderer.shared_context.base_url = base_url

    renderer.layout

    pdf_output_stream = java.io.FileOutputStream.new(pdf_file.path)
    renderer.create_pdf(pdf_output_stream)
    pdf_output_stream.close

    out_html.unlink

    pdf_file
  end

  def title_string
    @resource.finding_aid['title'] || @resource.finding_aid['filing_title'] || @resource.display_string
  end

  def resolved_repository
    @resource.repository['_resolved']
  end

  def repository_information
    @repo_info = {}
    @repo_info['top'] = {}
    unless resolved_repository.nil?
      %w(name uri url parent_institution_name image_url repo_code).each do |item|
        @repo_info['top'][item] = resolved_repository[item] unless resolved_repository[item].blank?
      end
      unless resolved_repository['agent_representation'].blank? || resolved_repository['agent_representation']['_resolved'].blank? || resolved_repository['agent_representation']['_resolved']['agent_contacts'].blank? || resolved_repository['agent_representation']['_resolved']['jsonmodel_type'] != 'agent_corporate_entity'
        in_h = resolved_repository['agent_representation']['_resolved']['agent_contacts'][0]
        %w{city region post_code country email }.each do |k|
          @repo_info[k] = in_h[k] if in_h[k].present?
        end
        if in_h['address_1'].present?
          @repo_info['address'] = []
          [1, 2, 3].each do |i|
            @repo_info['address'].push(in_h["address_#{i}"]) if in_h["address_#{i}"].present?
          end
        end
        @repo_info['telephones'] = in_h['telephones'] if !in_h['telephones'].blank?
      end
    end
    @repo_info
  end

  def t(str)
    I18n.t(str)
  end

  def each_ao
    page_size = 50

    @ordered_records.entries.drop(1).each_slice(page_size) do |entry_set|

      ao_list = []
      unprocessed_record_list = entry_set.map {|entry|
        id = JSONModel(:archival_object).id_for(entry.uri)
        json = ArchivalObject.to_jsonmodel(id)
        [PDF::ArchivalObject.new({"json" => URIResolver.resolve_references(
                                    ArchivalObject.to_jsonmodel(id),
                                    ['top_container', 'digital_object']
                                  )}), entry]
      }

      # tuple looks like [ArchivalObject, Entry]
      unprocessed_record_list.each_with_index do |tuple, i|
        record = tuple[0]
        next_record = unprocessed_record_list[i + 1][0] rescue nil

        next unless record.is_a?(PDF::ArchivalObject)

        if next_record && record.uri == next_record.parent_for_md_mapping
          has_children = true
        else
          has_children = false
        end

        tuple[2] = has_children

        yield record, tuple[1], has_children
      end
    end
  end
end
