# plugin/initializers/extent_ext.rb
JSONModel(:extent).schema['properties']['physical_description'] ||= {
  'type'        => 'string',
  'description' => 'The full unparsed physdesc text'
}
